// S3 장바구니 → 주문 생성 (결제 직전까지) — 로그인한 부하용 계정. 담기 → 장바구니 조회 → 주문 생성(PENDING: 포인트 · 재고 예약 · 결제 준비 Saga)
// 통과: p95 < 1.5s · 오류 < 1% · Saga 실패 0(Prometheus saga_failed_total). 주로 보는 곳: order · product(재고) · user(포인트) · 풀 · MySQL 연결
// 포트원 결제는 하지 않는다 — PENDING 주문은 15분 뒤 만료 보상으로 재고 · 포인트가 돌아온다(다음 측정 전 15분 휴지)
//   k6 run -e LOADTEST_PASSWORD=... loadtest/k6/s3-order.js     (10 → 30 → 60 VU)
import { check, sleep, group } from 'k6';
import { ORDER_OPTIONS, authHeaders, get, post, pick, think, stages, thresholds, summaryTo } from './lib.js';

export const options = {
  stages: __ENV.VUS ? [{ duration: '30s', target: Number(__ENV.VUS) }, { duration: __ENV.HOLD || '10m', target: Number(__ENV.VUS) }]
    : stages([10, 30, 60]),
  thresholds: thresholds(1500),
};

const ADDRESS = { receiverName: '부하테스트', receiverPhone: '010-9000-0000', zipcode: '04790', address1: '서울 성동구 왕십리로 1', address2: '부하',
  deliveryMemo: null, usePoint: 0 };

export function order() {
  const headers = authHeaders();
  const optionId = pick(ORDER_OPTIONS);
  group('장바구니', () => {
    check(post('/api/carts/items', { items: [{ productOptionId: optionId, quantity: 1 }] }, 'POST /api/carts/items', headers),
      { '담기 200': (r) => r.status === 200 || r.status === 201 });
    check(get('/api/carts', 'GET /api/carts', headers), { '장바구니 200': (r) => r.status === 200 });
  });
  sleep(think());
  group('주문 생성', () => {
    const res = post('/api/orders', { items: [{ productOptionId: optionId, quantity: 1 }], ...ADDRESS }, 'POST /api/orders', headers);
    // 201 = PENDING 주문 · 409 = 재고 소진(재고 옵션 목록을 다 쓰면) — 재고 소진은 측정 실패가 아니라 데이터 한계로 따로 셈
    check(res, { '주문 생성 201': (r) => r.status === 201 || r.status === 200, '5xx 아님': (r) => r.status < 500 });
  });
  sleep(think());
}

export default order;
export const handleSummary = summaryTo('s3-order');
