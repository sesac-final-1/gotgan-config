// S2 로그인 — 11/02 요청 제한(#204 · #205) 뒤로 "요청 제한이 동작하는지" 확인하는 시나리오로 바꿈 (확장 계획 5-7)
//   ① 한 IP 에서 POST 로그인 31번 → 31번째부터 429, 그 동안 다른 IP 의 로그인 · 로그인한 사용자의 조회는 통과
//   ② (선택) Keycloak 부하 — 계정마다 다른 IP 로 10 → 30 → 60 VU 로그인 · refresh. 통과: p95 < 1s
//   k6 run -e LOADTEST_PASSWORD=... loadtest/k6/s2-login-limit.js              (①만)
//   k6 run -e LOADTEST_PASSWORD=... -e KEYCLOAK=1 loadtest/k6/s2-login-limit.js (① + ②)
import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE, accountEmail, fakeIp, login, authHeaders, get, stages, summaryTo } from './lib.js';

const scenarios = {
  limit: { executor: 'per-vu-iterations', vus: 1, iterations: 1, exec: 'limit' },
};
if (__ENV.KEYCLOAK) {
  scenarios.keycloak = { executor: 'ramping-vus', startTime: '1m', stages: stages([10, 30, 60]), exec: 'keycloak' };
}

export const options = {
  scenarios,
  thresholds: { 'http_req_duration{scenario:keycloak}': ['p(95)<1000'], checks: ['rate>0.99'] },
};

export function limit() {
  const sameIp = { 'Content-Type': 'application/json', 'X-Vercel-Forwarded-For': '10.250.0.1' };
  // 없는 계정 · 틀린 비밀번호 — 401 이 와도 횟수는 센다. 부하용 계정(1번)으로 하면 Keycloak 무차별 대입 잠금(5회 실패 → 최대 15분)에 걸려
  // 뒤 시나리오(S4 · S5 · S3)의 1번 로그인이 401 로 멈춘다(11/4)
  const body = JSON.stringify({ email: 'loadtest-limit@gotgan.test', password: 'wrong-password-1!' });
  const codes = [];
  for (let i = 0; i < 36; i += 1) {   // 분당 30회 = 0.5개/초 보충 — 순차로 보내는 동안 토큰이 차서 31번째가 아닐 수 있다(11/5 33번째 429). 36번 안에 걸리면 동작
    codes.push(http.post(`${BASE}/api/auth/login`, body, { headers: sameIp, tags: { name: 'POST /api/auth/login (같은 IP)' } }).status);
  }
  check(codes, {
    '30번까지는 429 아님': (c) => c.slice(0, 30).every((s) => s !== 429),
    '36번 안에 429': (c) => c.includes(429),
  });
  // 다른 IP 의 로그인 · 로그인한 사용자의 일반 API 는 걸리지 않는다
  login(2);
  check(get('/api/users/me', 'GET /api/users/me', authHeaders()), { '다른 IP 로그인 · 조회 통과': (r) => r.status === 200 });
}

export function keycloak() {
  const res = http.post(`${BASE}/api/auth/login`, JSON.stringify({ email: accountEmail(__VU), password: __ENV.LOADTEST_PASSWORD }), {
    headers: { 'Content-Type': 'application/json', 'X-Vercel-Forwarded-For': fakeIp() }, tags: { name: 'POST /api/auth/login' },
  });
  check(res, { '로그인 200': (r) => r.status === 200 });
  for (let i = 0; i < 2; i += 1) {
    sleep(1);
    check(http.post(`${BASE}/api/auth/refresh`, null, { headers: { 'X-Vercel-Forwarded-For': fakeIp() }, tags: { name: 'POST /api/auth/refresh' } }),
      { 'refresh 200': (r) => r.status === 200 });
  }
  http.post(`${BASE}/api/auth/logout`, null, { headers: { 'X-Vercel-Forwarded-For': fakeIp() }, tags: { name: 'POST /api/auth/logout' } });
  sleep(1);
}

export const handleSummary = summaryTo('s2-login-limit');
