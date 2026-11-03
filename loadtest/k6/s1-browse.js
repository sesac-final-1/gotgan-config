// S1 둘러보기 (트래픽 대부분) — 비로그인. 카테고리 → 목록(카테고리 · 정렬 · 페이지) → 상세 → 리뷰 · 문의 → 스토어 홈
// 통과: p95 < 500ms · 오류 < 1%. 주로 보는 곳: gateway · product · review · store 메모리 · CPU · 풀
//   k6 run loadtest/k6/s1-browse.js            (단계 10 → 50 → 100 → 200 VU, 각 3분)
//   k6 run -e VUS=100 -e HOLD=30m ...           (S6 · S7 처럼 고정 부하로 쓸 때)
import { sleep, group } from 'k6';
import { check } from 'k6';
import { CATEGORIES, SUB_CATEGORIES, PRODUCTS, STORES, get, pick, think, stages, thresholds, summaryTo } from './lib.js';

const SORTS = ['NEW', 'PRICE_ASC', 'PRICE_DESC'];

export const options = {
  stages: __ENV.VUS ? [{ duration: '30s', target: Number(__ENV.VUS) }, { duration: __ENV.HOLD || '10m', target: Number(__ENV.VUS) }]
    : stages([10, 50, 100, 200]),
  thresholds: thresholds(500),
};

export function browse() {
  group('목록', () => {
    get('/api/categories', 'GET /api/categories');
    const byTop = Math.random() < 0.5;
    const res = get(`/api/products?${byTop ? `categoryId=${pick(CATEGORIES)}` : `categoryId=${pick(SUB_CATEGORIES)}`}&sort=${pick(SORTS)}&page=${Math.floor(Math.random() * 2)}&size=24`,
      'GET /api/products');
    check(res, { '목록 200': (r) => r.status === 200 });
    const ids = (res.json('data.content') || []).map((p) => p.productId);
    if (ids.length) get(`/api/reviews/ratings/products?ids=${ids.join(',')}`, 'GET /api/reviews/ratings/products');
  });
  sleep(think());

  const productId = pick(PRODUCTS);
  group('상세', () => {
    const res = get(`/api/products/${productId}`, 'GET /api/products/{id}');
    check(res, { '상세 200': (r) => r.status === 200 });
    get(`/api/reviews/summary?productId=${productId}`, 'GET /api/reviews/summary');
    get(`/api/reviews?productId=${productId}&photoOnly=false&sort=LATEST&page=0&size=10`, 'GET /api/reviews');
    get(`/api/inquiries?productId=${productId}&page=0&size=10`, 'GET /api/inquiries');
    get(`/api/stores/${Math.floor(productId / 100)}`, 'GET /api/stores/{id}');
  });
  sleep(think());

  if (Math.random() < 0.3) {
    group('스토어 홈', () => {
      const storeId = pick(STORES);
      get(`/api/stores/${storeId}`, 'GET /api/stores/{id}');
      get(`/api/products?storeId=${storeId}&sort=NEW&size=100`, 'GET /api/products');
      get(`/api/reviews/ratings/stores?ids=${storeId}`, 'GET /api/reviews/ratings/stores');
    });
    sleep(think());
  }
}

export default browse;
export const handleSummary = summaryTo('s1-browse');
