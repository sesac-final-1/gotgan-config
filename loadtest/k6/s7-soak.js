// S7 혼합 30분 유지(soak) — S1 70% · S3 20% · 로그인/refresh 10%, 1단계에서 찾은 한계의 70% 로 고정
// 통과: 메모리가 계속 오르지 않을 것 · 재시작 0 — 이 구간 working set 안정값이 memory requests 를 정한다(확장 계획 5-4)
//   k6 run -e LOADTEST_PASSWORD=... -e VUS=<한계의 70%> loadtest/k6/s7-soak.js
import http from 'k6/http';
import { sleep } from 'k6';
import { BASE, fakeIp, authHeaders, thresholds, summaryTo } from './lib.js';
import { browse } from './s1-browse.js';
import { order } from './s3-order.js';

const VUS = Number(__ENV.VUS || 70);
const DURATION = __ENV.HOLD || '30m';

export const options = {
  scenarios: {
    browse: { executor: 'constant-vus', vus: Math.max(1, Math.round(VUS * 0.7)), duration: DURATION, exec: 'browse' },
    order: { executor: 'constant-vus', vus: Math.max(1, Math.round(VUS * 0.2)), duration: DURATION, exec: 'order' },
    auth: { executor: 'constant-vus', vus: Math.max(1, Math.round(VUS * 0.1)), duration: DURATION, exec: 'refresh' },
  },
  thresholds: thresholds(1000),
};

export { browse, order };

// 로그인 유지 중인 사용자의 토큰 재발급 — 첫 반복에 로그인(Refresh Token 쿠키), 이후 refresh 만 (로그인 몰림은 S2)
export function refresh() {
  authHeaders();
  http.post(`${BASE}/api/auth/refresh`, null, { headers: { 'X-Vercel-Forwarded-For': fakeIp() }, tags: { name: 'POST /api/auth/refresh' } });
  sleep(5);
}

export const handleSummary = summaryTo('s7-soak');
