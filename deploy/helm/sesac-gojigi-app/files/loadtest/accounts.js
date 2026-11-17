// 관리자 화면 「계정 준비」(11/16) — 부하용 구매자 계정 loadtest+1 ~ COUNT 를 회원가입 API 로 만든다. 담당 구지훈
// 매일 08:00 클러스터가 빈 DB 로 시작해 리허설 · 발표 날 아침에 한 번. loadtest/k6/accounts.js 와 같은 규칙(PC 실행용 원본)
// 동시 가입 6개 — 서버가 파드당 5개(user 2파드 합 10)까지만 받아서(backend #234). 이미 있으면 409 = 성공
// BASE_URL · LOADTEST_PASSWORD 는 admin 이 Job 환경 변수와 loadtest-secret 으로 넣는다
import http from 'k6/http';
import exec from 'k6/execution';
import { check } from 'k6';

const BASE = __ENV.BASE_URL;
const PASSWORD = __ENV.LOADTEST_PASSWORD;
const COUNT = Number(__ENV.COUNT || 300);
if (!BASE || !PASSWORD) exec.test.abort('BASE_URL · LOADTEST_PASSWORD 가 없습니다 — admin-service Job 환경 변수 · loadtest-secret 확인');

export const options = {
  scenarios: { signup: { executor: 'shared-iterations', vus: 6, iterations: COUNT, maxDuration: '5m' } },
};

const ip = (n) => `10.${(n >> 16) & 255}.${(n >> 8) & 255}.${n & 255}`;   // 가입은 IP 당 분당 30회 — 계정마다 다른 가상 IP

export default function () {
  const no = exec.scenario.iterationInTest + 1;
  const res = http.post(`${BASE}/api/auth/signup`, JSON.stringify({
    email: `loadtest+${no}@gotgan.test`, password: PASSWORD, name: `부하${no}`, phone: `010-9000-${String(no).padStart(4, '0')}`,
  }), { headers: { 'Content-Type': 'application/json', 'X-Vercel-Forwarded-For': ip(no), 'X-Gotgan-Loadtest': '1' }, tags: { name: 'POST /api/auth/signup' } });
  check(res, { '가입 201 · 이미 있음 409': (r) => r.status === 201 || r.status === 409 });
}
