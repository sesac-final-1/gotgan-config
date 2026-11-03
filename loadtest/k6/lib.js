// k6 공통 — 주소 · 단계 · 통과 기준 · 로그인 · 가상 IP. 담당 구지훈
// 실행 방법 · 시나리오 설명은 loadtest/README.md, 판단 규칙은 노션 「확장성 · 메모리 점검과 확장 계획」 5장
import http from 'k6/http';
import { check, fail, sleep } from 'k6';
import exec from 'k6/execution';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.1.0/index.js';

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

// 가입 규칙과 같은지 먼저 본다(user SignupRequest · Keycloak 정책: 8~64자 · 영문 · 특수문자) — 틀리면 가입 400 · 로그인 401 로만 보여 원인을 찾기 어렵다
export function requirePassword() {
  const password = __ENV.LOADTEST_PASSWORD;
  if (!password) exec.test.abort('LOADTEST_PASSWORD 가 없습니다 — k6 run -e LOADTEST_PASSWORD=... (README 3절)');
  if (password.length < 8 || password.length > 64 || !/[A-Za-z]/.test(password) || !/[^A-Za-z0-9]/.test(password)) {
    exec.test.abort('LOADTEST_PASSWORD 가 가입 규칙에 맞지 않습니다 — 8~64자 · 영문 · 특수문자 1개 이상');
  }
  return password;
}

export function login(n = exec.vu.idInTest) {
  const password = requirePassword();
  const res = http.post(`${BASE}/api/auth/login`, JSON.stringify({ email: accountEmail(n), password }), {
    headers: { 'Content-Type': 'application/json', ...anonHeaders() }, tags: { name: 'POST /api/auth/login' },
  });
  if (!check(res, { '로그인 200': (r) => r.status === 200 })) {
    // 400 · 401 = 계정이 없거나 비밀번호가 다름 — 반복해도 같으므로 바로 멈춘다(쉬지 않고 반복하면 로그인 요청 제한 429 까지 감, 11/3 확인 실행)
    if (res.status === 400 || res.status === 401) {
      exec.test.abort(`로그인 실패 ${accountEmail(n)} → ${res.status} — accounts.js 로 계정을 만들었는지 · 같은 비밀번호인지 확인`);
    }
    sleep(5);   // 429 · 5xx — 잠깐 쉬고 다음 반복에서 다시
    fail(`로그인 실패 ${accountEmail(n)} → ${res.status}`);
  }
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
      stdout: `${textSummary(data, { indent: ' ', enableColors: true })}\n\n${name} 끝 — results/${name}-${stamp}.json\n`,   // 화면 요약 + 저장 위치
    };
  };
}
