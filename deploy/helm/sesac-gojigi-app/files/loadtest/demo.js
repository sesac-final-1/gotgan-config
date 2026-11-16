// 관리자 화면 부하테스트(11/16) — admin-service 가 만든 k6 Job 이 실행한다. 담당 구지훈
// 사용자 수는 실행 중에 admin 이 k6 REST API(6565, PATCH /v1/status)로 바꾼다 → externally-controlled 실행기.
//   이 실행기는 k6 v2 에서 빠져 이미지는 grafana/k6:1.8.3 으로 고정한다(admin 설정 app.loadtest.image)
// 지표는 Prometheus remote write(-o experimental-prometheus-rw, 5초)로 보내고 관리자 화면이 testid 태그로 조회한다
// 상품 · 옵션 번호는 loadtest/k6/lib.js 와 같은 시드 기준(gotgan-backend scripts/seed-gen)
import http from 'k6/http';
import { check, sleep } from 'k6';
import exec from 'k6/execution';

const BASE = __ENV.BASE_URL || 'http://gateway-service.sesac-gojigi.svc:443';   // 클러스터 안 게이트웨이(NLB 가 TLS 를 끝내 Service 443 → 파드 8080 은 http)
const SCENARIO = __ENV.SCENARIO || 'browse';

export const options = {
  scenarios: {
    demo: {
      executor: 'externally-controlled',
      vus: Number(__ENV.VUS || 10),
      maxVUs: Number(__ENV.MAX_VUS || 300),
      duration: __ENV.DURATION || '5m',
    },
  },
  summaryTrendStats: ['avg', 'p(95)'],
};

const CATEGORIES = [1, 2, 3, 4, 5, 6];
const PRODUCTS = [101, 102, 103, 104, 201, 202, 203, 204, 1101, 1102, 1104, 1201, 1202, 1203, 1204, 1301, 1302, 1303, 1304, 1305,
  1701, 1702, 1704, 1801, 1802, 1803, 1804, 1805, 1901, 1902, 1903, 1904];
const CART_OPTIONS = [10101, 10102, 10103, 10401, 10402, 10403, 120101, 120102, 120103, 120104, 120105, 120106, 120107, 120108,
  170101, 170102, 170103, 170104, 180101, 180102, 180201, 180301, 180302, 180303, 180401, 180402, 180403];

const pick = (list) => list[Math.floor(Math.random() * list.length)];
const think = (min = 1, max = 3) => sleep(min + Math.random() * (max - min));

// 비로그인 요청 출처 — VU 마다 고정 가상 IP(요청 제한 키). loadtest/k6/lib.js 와 같은 방식
const vu = () => exec.vu.idInTest;
const fakeIp = () => `10.${(vu() >> 16) & 255}.${(vu() >> 8) & 255}.${vu() & 255}`;
const anon = () => ({ 'X-Vercel-Forwarded-For': fakeIp() });
const get = (path, name, headers = anon()) => http.get(`${BASE}${path}`, { headers, tags: { name } });

// ── ① 둘러보기 (R) — 목록 → 상세 → 리뷰 · 스토어
function browse() {
  const list = get(`/api/products?categoryId=${pick(CATEGORIES)}&sort=NEW&page=0&size=24`, 'GET /api/products');
  check(list, { '목록 200': (r) => r.status === 200 });
  think();
  const productId = pick(PRODUCTS);
  check(get(`/api/products/${productId}`, 'GET /api/products/{id}'), { '상세 200': (r) => r.status === 200 });
  get(`/api/reviews/summary?productId=${productId}`, 'GET /api/reviews/summary');
  get(`/api/reviews?productId=${productId}&photoOnly=false&sort=LATEST&page=0&size=10`, 'GET /api/reviews');
  get(`/api/stores/${Math.floor(productId / 100)}`, 'GET /api/stores/{id}');
  think();
}

// ── ② 리뷰 조회 폭주 (R) — review 서비스로 트래픽을 몰아 두고 관리자 화면에서 review 를 내린다
function reviews() {
  const productId = pick(PRODUCTS.slice(0, 8));
  const res = get(`/api/reviews?productId=${productId}&photoOnly=false&sort=LATEST&page=0&size=10`, 'GET /api/reviews');
  check(res, { '리뷰 200': (r) => r.status === 200 });
  get(`/api/reviews/summary?productId=${productId}`, 'GET /api/reviews/summary');
  think(0.5, 1.5);
}

// ── ③ 장바구니 CRUD (C · R · U · D) — VU 마다 부하용 계정 loadtest+{번호}@gotgan.test(아침에 accounts.js 로 생성)
//   주문은 만들지 않는다(재고 · 결제 대기 정리 50분 — loadtest/README 2절)
const session = { token: null };

function login() {
  sleep(Math.random() * 5);   // 슬라이더로 사용자를 한꺼번에 늘릴 때 로그인이 Keycloak 에 몰리지 않게 흩뜨린다
  const res = http.post(`${BASE}/api/auth/login`,
    JSON.stringify({ email: `loadtest+${vu()}@gotgan.test`, password: __ENV.LOADTEST_PASSWORD }),
    { headers: { 'Content-Type': 'application/json', ...anon() }, tags: { name: 'POST /api/auth/login' } });
  if (!check(res, { '로그인 200': (r) => r.status === 200 })) {
    sleep(5);   // 계정이 없거나 요청 제한 — 시연을 멈추지 않고 다음 반복에서 다시
    return false;
  }
  session.token = res.json('data.accessToken');
  return true;
}

function cart() {
  if (!session.token && !login()) return;
  const headers = { Authorization: `Bearer ${session.token}`, 'Content-Type': 'application/json' };
  const optionId = pick(CART_OPTIONS);
  const add = http.post(`${BASE}/api/carts/items`, JSON.stringify({ items: [{ productOptionId: optionId, quantity: 1 }] }),
    { headers, tags: { name: 'POST /api/carts/items' } });
  if (add.status === 401) { session.token = null; return; }   // 토큰 만료(30분) — 다음 반복에서 다시 로그인
  check(add, { '담기 200': (r) => r.status === 200 });
  think(0.5, 1.5);
  check(http.get(`${BASE}/api/carts`, { headers, tags: { name: 'GET /api/carts' } }), { '조회 200': (r) => r.status === 200 });
  think(0.5, 1.5);
  http.patch(`${BASE}/api/carts/items/${optionId}`, JSON.stringify({ quantity: 2 }), { headers, tags: { name: 'PATCH /api/carts/items/{id}' } });
  think(0.5, 1.5);
  http.del(`${BASE}/api/carts/items?productOptionIds=${optionId}`, null, { headers, tags: { name: 'DELETE /api/carts/items' } });
  think();
}

// ── ④ 혼합 — VU 번호로 나눔: 10명 중 3명 장바구니, 7명 둘러보기
const mixed = () => (vu() % 10 < 3 ? cart() : browse());

const SCENARIOS = { browse, reviews, cart, mixed };

export default function () {
  (SCENARIOS[SCENARIO] || browse)();
}
