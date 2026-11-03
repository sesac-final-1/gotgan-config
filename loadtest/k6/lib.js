// k6 공통 — 주소 · 단계 · 통과 기준 · 로그인 · 가상 IP. 담당 구지훈
// 실행 방법 · 시나리오 설명은 loadtest/README.md, 판단 규칙은 노션 「확장성 · 메모리 점검과 확장 계획」 5장
import http from 'k6/http';
import { check, fail } from 'k6';
import exec from 'k6/execution';

export const BASE = __ENV.BASE_URL || 'https://api.gotgan.click';

// ── 시드 데이터 (gotgan-backend scripts/seed-gen/scenario.mjs — 상품 id = 스토어 × 100 + 순번, 옵션 = 상품 × 100 + 조합 순번)
export const CATEGORIES = [1, 2, 3, 4, 5, 6];
export const SUB_CATEGORIES = [101, 102, 103, 104, 201, 202, 203, 204, 205, 206, 301, 302, 303, 304, 305, 306, 401, 402, 403, 404, 405, 501, 502, 503, 504, 601, 602, 603];
export const STORES = [1, 2, 11, 12, 13, 17, 18, 19];   // 운영 중 (15 는 정지)
export const PRODUCTS = [101, 102, 103, 104, 201, 202, 203, 204, 1101, 1102, 1104, 1201, 1202, 1203, 1204, 1301, 1302, 1303, 1304, 1305,
  1701, 1702, 1704, 1801, 1802, 1803, 1804, 1805, 1901, 1902, 1903, 1904];
// 주문 시나리오용 — 재고가 넉넉한 옵션(조합당 수십 ~ 수백 개). 결제 전 주문(PENDING)이 재고를 잡고 15분 뒤 만료되면 돌려준다
export const ORDER_OPTIONS = [10101, 10102, 10103, 10401, 10402, 10403, 120101, 120102, 120103, 120104, 120105, 120106, 120107, 120108,
  170101, 170102, 170103, 170104, 180101, 180102, 180201, 180301, 180302, 180303, 180401, 180402, 180403];

export const pick = (list) => list[Math.floor(Math.random() * list.length)];
export const think = (min = 1, max = 3) => min + Math.random() * (max - min);

// ── 비로그인 요청의 출처 IP — 실제로는 Vercel 이 사용자 IP 를 X-Vercel-Forwarded-For 에 넣는다.
//   k6 는 Vercel 을 거치지 않으므로 VU 마다 고정된 가상 IP 를 넣어 "사용자 N명"으로 보이게 한다(넣지 않으면 모두 키 하나 → 초당 20회에서 429).
//   이 헤더를 클라이언트가 직접 넣을 수 있다는 점 자체가 알려진 약점(2차 방어선 미적용) — 발표에서 다룸
export const fakeIp = (vu = exec.vu.idInTest) => `10.${(vu >> 16) & 255}.${(vu >> 8) & 255}.${vu & 255}`;
export const anonHeaders = () => ({ 'X-Vercel-Forwarded-For': fakeIp() });

// ── 로그인한 VU — VU 마다 부하용 계정 하나(loadtest+{번호}@gotgan.test). 비밀번호는 실행하는 사람이 -e LOADTEST_PASSWORD=… 로 넣는다
//   Access Token 30분 — 25분이 지나면 refresh(Refresh Token 은 HttpOnly 쿠키라 VU 쿠키 통에 저장돼 같이 간다)
const session = { token: null, at: 0 };
export const accountEmail = (n) => `loadtest+${n}@gotgan.test`;

export function login(n = exec.vu.idInTest) {
  const password = __ENV.LOADTEST_PASSWORD;
  if (!password) fail('LOADTEST_PASSWORD 가 없습니다 — k6 run -e LOADTEST_PASSWORD=... (README 3절)');
  const res = http.post(`${BASE}/api/auth/login`, JSON.stringify({ email: accountEmail(n), password }), {
    headers: { 'Content-Type': 'application/json', ...anonHeaders() }, tags: { name: 'POST /api/auth/login' },
  });
  if (!check(res, { '로그인 200': (r) => r.status === 200 })) fail(`로그인 실패 ${accountEmail(n)} → ${res.status} (계정 생성: accounts.js)`);
  session.token = res.json('data.accessToken');
  session.at = Date.now();
  return session.token;
}

export function authHeaders() {
  if (!session.token) login();
  if (Date.now() - session.at > 25 * 60 * 1000) {
    const res = http.post(`${BASE}/api/auth/refresh`, null, { headers: anonHeaders(), tags: { name: 'POST /api/auth/refresh' } });
    if (res.status === 200) {
      session.token = res.json('data.accessToken');
      session.at = Date.now();
    } else {
      login();
    }
  }
  return { Authorization: `Bearer ${session.token}`, 'Content-Type': 'application/json' };
}

// ── 요청 도우미 — 이름 태그로 묶어(경로 id 를 지움) 결과표가 엔드포인트별로 나오게
export const get = (path, name, headers = anonHeaders()) => http.get(`${BASE}${path}`, { headers, tags: { name } });
export const post = (path, body, name, headers) => http.post(`${BASE}${path}`, JSON.stringify(body), { headers, tags: { name } });

// ── 통과 기준 (확장 계획 5-2). 429(요청 제한)와 5xx · 504(게이트웨이 타임아웃)는 따로 센다 — 아래 상태 태그로 결과에 나뉜다
export const thresholds = (p95ms) => ({
  http_req_duration: [`p(95)<${p95ms}`],
  http_req_failed: ['rate<0.01'],
  checks: ['rate>0.99'],
});

// 3분 유지 단계 — [VU …] → stages
export const stages = (targets, hold = '3m', ramp = '30s') => targets.flatMap((t) => [{ duration: ramp, target: t }, { duration: hold, target: t }]);

// 결과 저장 — --summary-export 대신 시나리오 이름 · 시각으로 results/ 에 JSON
export function summaryTo(name) {
  return (data) => {
    const stamp = new Date().toISOString().replace(/[:.]/g, '-');
    return {
      [`loadtest/results/${name}-${stamp}.json`]: JSON.stringify(data, null, 2),
      stdout: `\n${name} 끝 — results/${name}-${stamp}.json\n`,
    };
  };
}
