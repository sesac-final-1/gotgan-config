// S4 한정 재고 동시 주문 — 성능보다 정확성. 재고 10개 옵션에 100 VU 가 동시에 1개씩 주문 → 성공 정확히 10건 · 초과 판매 0
// 준비: 옵션 하나를 재고 10 으로(기본 OPTION=10201 — 지리산 야생화 꿀, 단일 옵션). S3 · S7 이 쓰는 ORDER_OPTIONS 에 없는 옵션이라
//   S3 재고와 섞이지 않는다(11/4 — 10402 는 ORDER_OPTIONS 에 있어 S3 주문이 S4 재고를 먹음). README 4절
//   k6 run -e LOADTEST_PASSWORD=... loadtest/k6/s4-stock-race.js
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';
import { login, authHeaders, post, summaryTo } from './lib.js';

const OPTION = Number(__ENV.OPTION || 10201);
const created = new Counter('orders_created');
const rejected = new Counter('orders_rejected');

export const options = {
  scenarios: { race: { executor: 'per-vu-iterations', vus: 100, iterations: 1, maxDuration: '3m' } },
  thresholds: { orders_created: ['count==10'], checks: ['rate==1'] },
};

// 모두 로그인을 마친 뒤 같은 시각에 주문 — 로그인 시간 차이로 경합이 흩어지지 않게
export function setup() {
  return { startAt: Date.now() + 60 * 1000 };
}

export default function (data) {
  login();
  sleep(Math.max(0, (data.startAt - Date.now()) / 1000));
  const res = post('/api/orders', { items: [{ productOptionId: OPTION, quantity: 1 }], receiverName: '부하테스트', receiverPhone: '010-9000-0000',
    zipcode: '04790', address1: '서울 성동구 왕십리로 1', address2: '재고 경합', deliveryMemo: null, usePoint: 0 }, 'POST /api/orders (경합)', authHeaders());
  if (res.status === 200 || res.status === 201) created.add(1);
  else rejected.add(1, { status: String(res.status) });
  check(res, { '성공 또는 재고 부족(4xx) — 5xx 아님': (r) => r.status < 500 });
}

export const handleSummary = summaryTo('s4-stock-race');
