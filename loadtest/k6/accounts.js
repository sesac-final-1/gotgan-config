// 부하용 구매자 계정 만들기 — 회원가입 API 로(Keycloak 을 직접 만지지 않음). 매일 08:00 클러스터가 빈 DB 로 시작하므로 측정하는 날 한 번
//   k6 run -e LOADTEST_PASSWORD=... -e COUNT=200 loadtest/k6/accounts.js
// 계정 번호 1 ~ COUNT — 다른 시나리오의 login() 이 VU 번호로 같은 계정을 쓴다.
// 동시 가입은 CONCURRENCY(기본 6)개까지 — 200개를 한 번에 보내면 user-service → Keycloak 호출이
//   "too many concurrent streams" · 3초 타임아웃으로 70% 실패하고, Keycloak 에만 계정이 남았다(11/4 첫 실행)
//   backend #234 뒤로는 서버가 파드당 동시 5개(user 2파드 합 10)까지만 받고 나머지는 503(AUTH_SIGNUP_BUSY) — CONCURRENCY=200 은 체크가 실패로 나오는 것이 정상.
//   합격 = 502 0건 · 정리 뒤(약 5초) Keycloak users/count = 회원 DB 수 → 같은 번호로 CONCURRENCY=6 재실행하면 체크 통과(거절된 계정이 가입됨)
// 가입은 IP 당 분당 30회 제한(POST 로그인 · 가입) — 계정마다 다른 가상 IP. 이미 있으면(409) 성공으로 친다
import http from 'k6/http';
import exec from 'k6/execution';
import { check } from 'k6';
import { BASE, accountEmail, fakeIp, requirePassword } from './lib.js';

const COUNT = Number(__ENV.COUNT || 200);
const CONCURRENCY = Number(__ENV.CONCURRENCY || 6);

export const options = {
  scenarios: { signup: { executor: 'shared-iterations', vus: Math.min(CONCURRENCY, COUNT), iterations: COUNT, maxDuration: '5m' } },
  thresholds: { checks: ['rate>0.99'] },
};

export default function () {
  const no = exec.scenario.iterationInTest + 1;
  const password = requirePassword();
  const res = http.post(`${BASE}/api/auth/signup`, JSON.stringify({
    email: accountEmail(no), password, name: `부하${no}`, phone: `010-9000-${String(no).padStart(4, '0')}`,
  }), { headers: { 'Content-Type': 'application/json', 'X-Vercel-Forwarded-For': fakeIp(no) }, tags: { name: 'POST /api/auth/signup' } });
  if (!check(res, { '가입 201 · 이미 있음 409': (r) => r.status === 201 || r.status === 409 })) {
    console.error(`가입 실패 ${accountEmail(no)} → ${res.status} ${res.json('message') ?? ''}`);   // 400 이면 서버 입력 검사 메시지
  }
}
