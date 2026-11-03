// 부하용 구매자 계정 만들기 — 회원가입 API 로(Keycloak 을 직접 만지지 않음). 매일 08:00 클러스터가 빈 DB 로 시작하므로 측정하는 날 한 번
//   k6 run -e LOADTEST_PASSWORD=... -e COUNT=200 loadtest/k6/accounts.js
// VU 하나 = 계정 하나(번호 = VU 번호) — 다른 시나리오의 login() 이 같은 번호를 쓴다.
// 가입은 IP 당 분당 30회 제한(POST 로그인 · 가입) — 계정마다 다른 가상 IP 라 한 번에 만든다. 이미 있으면(409) 성공으로 친다
import http from 'k6/http';
import { check } from 'k6';
import { BASE, accountEmail, fakeIp } from './lib.js';

const COUNT = Number(__ENV.COUNT || 200);

export const options = {
  scenarios: { signup: { executor: 'per-vu-iterations', vus: COUNT, iterations: 1, maxDuration: '5m' } },
  thresholds: { checks: ['rate>0.99'] },
};

export default function () {
  const no = __VU;
  const res = http.post(`${BASE}/api/auth/signup`, JSON.stringify({
    email: accountEmail(no), password: __ENV.LOADTEST_PASSWORD, name: `부하${no}`, phone: `010-9000-${String(no).padStart(4, '0')}`,
  }), { headers: { 'Content-Type': 'application/json', 'X-Vercel-Forwarded-For': fakeIp(no) }, tags: { name: 'POST /api/auth/signup' } });
  check(res, { '가입 201 · 이미 있음 409': (r) => r.status === 201 || r.status === 409 });
}
