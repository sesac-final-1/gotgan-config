# 부하테스트 (k6) — 곳간

> 담당 구지훈 · 계획 · 판단 규칙: 노션 「확장성 · 메모리 점검과 확장 계획」 5장(시나리오 S1 ~ S7 · 5-4 판단 규칙 · 5-7 요청 제한 · 5-8 레플리카 확인표)
> 일정: **11/4(수) 오후 기준선 → 11/5(목) 오전 값 적용 → 오후 재측정**. 측정 시간에는 동작이 바뀌는 머지 · ArgoCD 변경을 멈춘다

## 1. 파일

| 파일 | 내용 | 로그인 |
|---|---|---|
| `k6/lib.js` | 주소(`BASE_URL`, 기본 `https://api.gotgan.click`) · 시드 상품 · 옵션 번호 · 가상 IP · 로그인/refresh · 통과 기준 · 결과 저장 | — |
| `k6/accounts.js` | 부하용 구매자 계정 `loadtest+{번호}@gotgan.test` 를 회원가입 API 로 만든다(번호 = VU 번호) | 비밀번호 필요 |
| `k6/s1-browse.js` | **S1 둘러보기** — 비로그인, 10 → 50 → 100 → 200 VU · 각 3분. p95 < 500ms | — |
| `k6/s2-login-limit.js` | **S2 로그인** — 같은 IP 36번 안에 로그인 429 확인 + (선택 `KEYCLOAK=1`) 10 → 60 VU 로그인 · refresh. p95 < 1s | 필요 |
| `k6/s3-order.js` | **S3 장바구니 → 주문 생성**(결제 직전, PENDING) — 10 → 30 → 60 VU. p95 < 1.5s · Saga 실패 0 | 필요 |
| `k6/s4-stock-race.js` | **S4 한정 재고 동시 주문** — 재고 10 옵션에 100 VU 동시 1개 → 성공 정확히 10 | 필요 |
| `k6/s5-realtime.js` | **S5 실시간** — 채팅 WebSocket 50 → 200 → 500 연결(20% 는 1초 1건) · 알림 SSE 50 → 200 연결. 연결 > 99% · 왕복 p95 < 1s | 필요 |
| `k6/s6-aggregate.js` | **S6 둘러보기 + 정산 집계** — S1 100 VU 중 5분에 관리자 "지금 집계" | 관리자 |
| `k6/s7-soak.js` | **S7 혼합 30분** — S1 70% · S3 20% · refresh 10%, 한계의 70% | 필요 |
| `k6/s8-category-skew.js` | **S8 카테고리 쏠림**(멘토링 F-3) — 3분 고르게 → 5분 한 카테고리에 몰기(합 200 VU). 나머지 카테고리 p95 변화를 본다 | — |
| `prep-data.sh` | 측정 직전 데이터 — `stock`(부하용 재고) · `settlement`(정산 5,000건 · 압축 경로 포함) · `status` | 공유 DB 변경 — 공지 뒤 |
| `watch-db.sh` | 10초마다 MySQL 연결 · Redis 메모리 · ops · 파드 CPU/메모리 합 CSV + 끝날 때 쿼리 상위 5 | kubectl |
| `run.sh` | 한 시나리오 측정 묶음 — watch-db + k6(요청별 CSV · p99) + 종료 처리. `bash loadtest/run.sh s5 s5-realtime.js -e COUNT=200` | `.env` |
| `.env.example` | 비밀번호 파일 양식 — `loadtest/.env` 로 복사(Git 제외) | — |

결과는 `loadtest/results/`(Git 제외) — k6 요약 JSON · watch CSV · 쿼리 상위 5.

## 2. 실행 위치 · 주의

- 실행: 지훈님 PC 터미널(k6 설치됨) → `api.gotgan.click`(NLB → 게이트웨이, 실사용자와 같은 경로). PC 회선이 먼저 막히면(k6 의 `http_req_blocked` · `data_sent` 급증) 클러스터 안 k6 파드로 바꾼다.
- **요청 제한(11/02)**: 비로그인은 IP 당 초당 20회 — k6 가 VU 마다 `X-Vercel-Forwarded-For` 에 가상 IP 를 넣어 사용자 N명처럼 보이게 한다. 로그인 시나리오는 사용자 키라 영향 없음. 429 · 5xx · 504(게이트웨이 응답 10초 타임아웃)는 결과에서 상태별로 따로 본다.
- **비밀번호**는 명령줄 `-e` 로만 넣는다 — 파일 · 문서 · 채팅에 적지 않는다(관리자 계정은 시드 계정). 부하용 계정 비밀번호는 **가입 규칙(8~64자 · 영문 · 특수문자 1개 이상)** 을 따라야 하고, 맞지 않으면 스크립트가 요청을 보내기 전에 멈춘다. 특수문자가 셸에서 해석되지 않게 작은따옴표로 감싼다(`-e LOADTEST_PASSWORD='…'`, cmd 는 큰따옴표)
- 매일 08:00 빈 DB 로 다시 생성 → **측정하는 날 아침에 계정을 다시 만든다**(accounts.js, 약 1분).
- S3 · S4 · S7 은 재고를 잡는다. 결제 대기(PENDING) 주문은 15분 뒤 만료 보상으로 돌아오는데, **만료 처리는 분당 최대 100건**(order `scheduler.batch-size: 100` · 60초 간격). S3 는 약 4,600건을 만들어 다 정리되기까지 **약 50분** — 그동안 재고 반환 · 포인트 복구 호출이 다른 시나리오와 겹친다. 그래서 주문을 만드는 S3 · S7 을 **뒤로** 두고, S3 뒤에는 `watch-db.sh` 의 `pending_orders` 가 0 근처가 될 때까지 기다린 뒤 S7 (11/4)
- **kubectl 연결**: 매일 클러스터 주소가 바뀐다. 측정 전 `aws eks update-kubeconfig --name sesac-gojigi-eks-cluster --region ap-northeast-2` — `watch-db.sh` 는 EKS 에 닿지 않으면 시작하지 않는다
- **재고**: 측정하는 날 아침에 부하용 옵션(`lib.js` ORDER_OPTIONS 27개)의 재고를 크게(100,000) 올려 둔다 — 시드 재고 합 5,160 으로는 S3 60 VU 에서 재고 소진 409 가 섞인다(다음 날 초기화)

## 3. 순서 (한 시나리오씩 — 사이에 5분 휴지, 메모리 · 연결이 내려오는지 확인)

```bash
# 0) 계정 (측정하는 날 한 번)
k6 run -e LOADTEST_PASSWORD=<비밀번호> -e COUNT=200 loadtest/k6/accounts.js

# 1) 기록을 켜 둔 채(다른 터미널) 시나리오 실행 — 예: S1
RESET=1 bash loadtest/watch-db.sh s1
k6 run loadtest/k6/s1-browse.js

# 2) 나머지 — 주문을 만들지 않는 것 먼저, 주문을 만드는 S3 · S7 은 뒤로(2절 만료 처리량)
k6 run -e LOADTEST_PASSWORD=<비밀번호> loadtest/k6/s2-login-limit.js
k6 run -e LOADTEST_PASSWORD=<비밀번호> loadtest/k6/s4-stock-race.js         # 옵션 10201 재고 10 (4절)
k6 run -e LOADTEST_PASSWORD=<비밀번호> -e COUNT=200 loadtest/k6/s5-realtime.js
k6 run -e ADMIN_EMAIL=<관리자 이메일> -e ADMIN_PASSWORD=<비밀번호> loadtest/k6/s6-aggregate.js
k6 run -e LOADTEST_PASSWORD=<비밀번호> loadtest/k6/s3-order.js            # 끝나면 pending_orders 가 0 근처까지(약 50분)
k6 run -e LOADTEST_PASSWORD=<비밀번호> -e VUS=<S1·S3 한계의 70%> loadtest/k6/s7-soak.js   # 30분
```

> **`run.sh` 를 쓰면** 위 터미널 두 개가 한 번에 된다(11/4 측정에서 정리). 단계별 p95 · p99 는 `results/{이름}-{시각}.csv.gz` 에서 계산 — k6 요약은 전체 값 하나뿐이다. 백그라운드로 띄운 watch-db 는 Ctrl+C 가 닿지 않아 `kill -TERM` 으로 끝낸다.

## 4. 시나리오별 준비

- **S4**: 옵션 하나를 **재고 10** 으로 — 기본 `OPTION=10201`(지리산 야생화 꿀, 단일 옵션 · ORDER_OPTIONS 에 없어 S3 와 안 섞임). DB 로 맞추거나 seller1 판매자센터 「재고」. 끝나면 재고 원복은 필요 없음(다음 날 초기화).
- **S5**: 채팅은 Origin 을 확인한다 — 기본 `ORIGIN=https://gotgan-ashy.vercel.app`. 사용자당 연결 5개 제한(파드마다)이라 `COUNT`(계정 수)가 연결 수 / 5 보다 커야 한다(500 연결 → 200 계정이면 계정당 2.5).
- **S6**: 지난주 정산서가 이미 집계돼 있으면 "다시 집계"(멱등)라 빨리 끝난다 — 집계 시간보다 **S1 p95 변화**를 본다.

## 5. 같이 기록할 지표 (Grafana · Prometheus — 계획 5-1)

`container_memory_working_set_bytes` · `jvm_memory_used_bytes{area=heap|nonheap}` · `jvm_gc_pause_seconds_sum` · `jvm_threads_live_threads` · `kube_pod_container_status_restarts_total` · OOMKilled · `rate(container_cpu_usage_seconds_total[1m])` · `hikaricp_connections_active / pending / timeout_total` · `resilience4j_circuitbreaker_state` · `saga_failed_total`(실패가 없으면 지표 자체가 없음 → 0) · `saga_compensated_total` · `chat_ws_sessions` — 라벨은 `app` · `pod`. 서버 p95 는 응답 시간 구간 8칸(backend #227)으로 `histogram_quantile(0.95, sum by (le, app) (rate(http_server_requests_seconds_bucket[1m])))`

시나리오마다 결과는 `_notion/07_테스트/k6_결과_{날짜}_{시나리오}.md` 표 한 장으로 — **처음 무너진 단계 + 그때 병목**(메모리 · CPU · 풀 대기 · MySQL 연결 · Keycloak · Redis · 서킷)을 한 줄로.
