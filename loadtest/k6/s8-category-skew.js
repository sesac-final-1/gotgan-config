// S8 카테고리 쏠림 (멘토링 F-3) — 한 카테고리에 트래픽이 몰릴 때 다른 카테고리 응답이 함께 느려지는가. 담당 구지훈
// 앞 3분은 카테고리마다 고르게(기준), 30초 올린 뒤 5분은 HOT 카테고리에 몰아서(쏠림) 같은 "나머지 카테고리"의 p95 를 비교한다
// 상품 조회는 카테고리와 관계없이 product 서비스 하나가 처리 — 격리는 없으므로 같이 느려지는 것이 예상. 결과는 있는 그대로 기록한다
//   bash loadtest/run.sh s8 s8-category-skew.js                         (기본: HOT 식품 · 합 200 VU, 약 9분)
//   bash loadtest/run.sh s8 s8-category-skew.js -e HOT=3 -e HOT_VUS=360 -e OTHER_VUS=40
import { check, sleep } from 'k6';
import exec from 'k6/execution';
import { Trend } from 'k6/metrics';
import { CATEGORIES, get, pick, think, summaryTo } from './lib.js';

const HOT = Number(__ENV.HOT || 1);                  // 상위 카테고리 — 1 식품 · 2 리빙 · 3 패션의류 · 4 신발 · 가방 · 5 뷰티 · 6 디지털
const OTHER_VUS = Number(__ENV.OTHER_VUS || 40);     // 나머지 카테고리 — 내내 같은 부하
const HOT_VUS = Number(__ENV.HOT_VUS || 160);        // 쏠림 구간의 HOT 부하
const BASE_VUS = Math.max(1, Math.round(OTHER_VUS / (CATEGORIES.length - 1)));   // 기준 구간 HOT = 나머지 카테고리 한 곳과 같은 몫
const OTHERS = CATEGORIES.filter((c) => c !== HOT);

const BASE_SEC = 180;
const RAMP_SEC = 30;
const SKEW_SEC = 300;

const hotLatency = new Trend('category_hot', true);
const otherLatency = new Trend('category_other', true);

const phase = () => {
  const sec = exec.instance.currentTestRunDuration / 1000;
  if (sec < BASE_SEC) return 'base';
  return sec < BASE_SEC + RAMP_SEC ? 'ramp' : 'skew';
};

export const options = {
  scenarios: {
    hot: {
      executor: 'ramping-vus',
      exec: 'hot',
      startVUs: BASE_VUS,
      stages: [
        { duration: `${BASE_SEC}s`, target: BASE_VUS },
        { duration: `${RAMP_SEC}s`, target: HOT_VUS },
        { duration: `${SKEW_SEC}s`, target: HOT_VUS },
      ],
    },
    others: { executor: 'constant-vus', exec: 'others', vus: OTHER_VUS, duration: `${BASE_SEC + RAMP_SEC + SKEW_SEC}s` },
  },
  // 구간별 p95 를 요약에 남기려고 건다. 합격선은 S1 과 같은 500ms — 판단은 "나머지"의 기준 → 쏠림 변화로 한다
  thresholds: {
    'category_hot{phase:base}': ['p(95)<500'],
    'category_hot{phase:skew}': ['p(95)<500'],
    'category_other{phase:base}': ['p(95)<500'],
    'category_other{phase:skew}': ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

function browse(categoryId, metric) {
  const list = get(`/api/products?categoryId=${categoryId}&sort=NEW&page=0&size=20`, 'GET /api/products');
  metric.add(list.timings.duration, { phase: phase() });
  check(list, { '목록 200': (r) => r.status === 200 });
  sleep(think());
  const ids = list.status === 200 ? (list.json('data.content') || []).map((p) => p.productId) : [];
  if (ids.length) {
    const detail = get(`/api/products/${pick(ids)}`, 'GET /api/products/{id}');
    metric.add(detail.timings.duration, { phase: phase() });
    check(detail, { '상세 200': (r) => r.status === 200 });
  }
  sleep(think());
}

export function hot() { browse(HOT, hotLatency); }
export function others() { browse(pick(OTHERS), otherLatency); }

export const handleSummary = summaryTo('s8-category-skew');
