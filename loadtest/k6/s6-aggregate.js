// S6 둘러보기 + 정산 집계 — S1 을 100 VU 로 돌리는 중(5분 뒤) 관리자 "이 주차 지금 집계"를 한 번
// 통과: 집계 완료 시간 기록 · S1 p95 변화 < 20%(집계 전 ↔ 집계 중 구간 비교). 주로 보는 곳: settlement · MySQL
// 관리자 비밀번호는 실행하는 사람이 넣는다 — 관리자 계정은 시드 계정(문서에 비밀번호를 적지 않음)
//   k6 run -e ADMIN_EMAIL=... -e ADMIN_PASSWORD=... loadtest/k6/s6-aggregate.js
import http from 'k6/http';
import { check } from 'k6';
import { Trend } from 'k6/metrics';
import { BASE, fakeIp, summaryTo } from './lib.js';
import { browse } from './s1-browse.js';

const aggregateTime = new Trend('aggregate_duration', true);

export const options = {
  scenarios: {
    browse: { executor: 'constant-vus', vus: Number(__ENV.VUS || 100), duration: '12m', exec: 'browse' },
    aggregate: { executor: 'per-vu-iterations', vus: 1, iterations: 1, startTime: '5m', exec: 'aggregate' },
  },
  thresholds: { 'http_req_duration{scenario:browse}': ['p(95)<500'], aggregate_duration: ['max<60000'] },
};

export { browse };

export function aggregate() {
  const login = http.post(`${BASE}/api/auth/login`, JSON.stringify({ email: __ENV.ADMIN_EMAIL, password: __ENV.ADMIN_PASSWORD }), {
    headers: { 'Content-Type': 'application/json', 'X-Vercel-Forwarded-For': fakeIp(9999) }, tags: { name: 'POST /api/auth/login (관리자)' },
  });
  check(login, { '관리자 로그인 200': (r) => r.status === 200 });
  const res = http.post(`${BASE}/api/admin/settlements/aggregate`, JSON.stringify({}), {
    headers: { Authorization: `Bearer ${login.json('data.accessToken')}`, 'Content-Type': 'application/json' }, timeout: '120s',
    tags: { name: 'POST /api/admin/settlements/aggregate' },
  });
  aggregateTime.add(res.timings.duration);
  check(res, { '집계 200': (r) => r.status === 200 });
}

export const handleSummary = summaryTo('s6-aggregate');
