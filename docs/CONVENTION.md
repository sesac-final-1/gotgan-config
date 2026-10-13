# 곳간(GOTGAN) 코드 컨벤션

> 이 문서는 **규칙** 문서입니다. 규칙을 바꾸려면 팀 합의 후 이 문서를 수정하는 PR을 올립니다.
> 관련 문서: `project-spec.html`(무엇을 만드나) · `project-guideline.html`(왜 이렇게 만드나)

---

---

> **이 파일은 발췌본입니다.** 정본은 문서 사이트 컨벤션(https://gotganguide.vercel.app/convention)이고, 이 파일은 `gotgan-config`에 해당하는 인프라 · 배포 · 로그 부분만 자동 추출한 것입니다. 규칙을 바꾸려면 정본(gotgan_guide 저장소 `content/project-convention.md`)을 고치고 `split-convention`을 다시 실행합니다.

---

## 0. 개요

### 0-1. 판단 원칙

- **"어떻게 쓰나"는 팀 기존 규칙 우선** — 코드 스타일 · 네이밍 · 응답 형식 · 예외 구조 · DB 규칙
- **"무엇을 만드나"는 프로젝트 스펙 유지** — 서비스 9개 + Keycloak · 엔드포인트 · 이벤트 · 인프라 구성
- **MSA 전용 규칙 추가** — 서비스 간 호출 · Resilience4j · 대시보드 조합 · 이벤트 · Saga · 멱등성 · 인프라 네이밍
- 규칙끼리 충돌하면 이 문서가 우선, 다른 문서는 이 문서에 맞춰 수정

### 0-2. 기존 컨벤션 대비 변경 사항

| 항목 | 기존(따숨) | 곳간 | 이유 |
|---|---|---|---|
| 패키지 | 도메인형, 엔티티는 `domain/` | 도메인형, 엔티티는 **`entity/`**, 서비스 호출용 **`client/`** 추가 | 팀 합의(엔티티 패키지명) · 서비스 간 HTTP 호출 |
| 보안 위치 | 각 앱 `common/security` | **게이트웨이에만** Spring Security, 업무 서비스는 `common/auth`(헤더 → 사용자) | 토큰 발급은 Keycloak, JWT 검증은 게이트웨이 한 곳 |
| 로그인 사용자 | `SecurityUtil.getMemberId()` | `@CurrentUser AuthUser` (게이트웨이가 넣은 `X-User-*` 헤더) | 업무 서비스에 SecurityContext 없음 |
| FK 제약 | 참조 컬럼 FK 필수 | **같은 서비스 안에서만 FK 필수**, 다른 서비스 ID는 논리 참조 + 인덱스 | DB per Service |
| 회원 테이블 · 패키지 | `member` · `member/` | **`users` · `user/`** | 서비스(user-service) · 스키마(userdb) 이름과 일치 |
| 테이블명 예외 | 단수형 | 단수형 유지, **`orders`**(예약어 `order`) · **`users`**(키워드 `user`)만 예외 | MySQL 예약어 · 키워드 |
| 에러 코드 | 번호형 `ORDER_003` | **의미형 `ORDER_OUT_OF_STOCK`** | 코드만 봐도 의미 · 로그 검색 |
| 시드 데이터 | `db/seed` V100~ | `db/seed/R__*.sql` (반복 실행) | 내용 수정 시 체크섬 오류 없음 |
| 프론트 언어 | TypeScript | **JavaScript** (`.js` / `.jsx`) | 목업 그대로 이식 · 입문자 부담 최소화 |
| 프론트 UI 키트 | shadcn/ui · recharts · sonner | **목업 컴포넌트 · 목업 SVG 차트 · 목업 토스트** | 목업 디자인 원칙 유지 |
| 프론트 관리자 | `features/admin` 공유 도메인 | **`features/admin`** — admin-service(`/api/admin/**`)만 호출, 담당 구지훈 | 백엔드 admin-service와 1:1 대칭, 담당 = 폴더 담당 |
| 프론트 페이지 | — | `pages/{shop,mypage,seller,admin}` | 4개 화면 영역 |

### 0-3. 확정 컨벤션 요약

팀 회의에서 확정한 8가지입니다. `project-spec.html`과 다르면 이 표가 우선합니다.

| # | 항목 | 확정 규칙 | 관련 절 |
|---|---|---|---|
| 1 | API 응답 형식 | 모든 응답을 `ApiResponse<T>` 봉투 `{ code, message, data }` 하나로 | 2-4 · 2-5 |
| 2 | 시간대 | DB · JDBC · JVM 모두 Asia/Seoul, 서비스 밖으로 나가는 이벤트 시각만 오프셋 포함 | 3-5 |
| 3 | 회원 테이블 · 패키지명 | 테이블 `users`, 패키지 `user/`, 엔티티 `User` | 2-1 · 3-2 |
| 4 | 생성 · 수정 시각 관리 | DB `DEFAULT` · `ON UPDATE`로 기록, 엔티티는 `@Generated`로 읽기만 | 3-5 |
| 5 | 에러 코드 형식 | 의미형 `{도메인}_{상황}` — `ORDER_OUT_OF_STOCK` | 2-5 |
| 6 | 프론트 언어 | JavaScript (`.js` / `.jsx`) — 목업 그대로 | 4-1 |
| 7 | 프론트 페이지 위치 | `pages/{shop · mypage · seller · admin}/` — 로직은 `features/` | 4-2 |
| 8 | Redis 키 이름 | `{용도}:{식별자}` — `cart:{userId}`(캐시, 원본은 `orderdb.cart_item`) · `blacklist:{jti}`(Could). 리프레시 토큰 키는 폐지(Keycloak이 관리) | 2-2 |

### 0-4. 10/12 추가 확정

| 항목 | 확정 규칙 | 관련 절 |
|---|---|---|
| 서비스 구성 | Spring 9개(gateway · user · store · product · order · payment · review · settlement · admin) + Keycloak | 2-1 · 3-2 |
| admin-service | DB 없는 조합 계층 — 관리자 API 진입점, 각 서비스 `/internal/**`을 호출해 조합만 | 2-1 · 2-4 · 2-7 |
| 카테고리 · 수수료 | 카테고리는 product-service, 카테고리별 수수료는 settlement-service | 2-1 · 3-2 |
| 대시보드 | 판매자는 store, 관리자는 admin 안에서 조합 — 병렬 호출 + 실패 영역만 빼고 부분 응답 | 2-7 |
| 서비스 간 호출 | Resilience4j 표준 (타임아웃 · 서킷 브레이커 · 멱등 GET만 재시도 · 폴백) | 2-7 |
| 동적 검색 | QueryDSL | 2-6 |
| XSS | 사용자 입력 HTML은 OWASP Java HTML Sanitizer로 저장 전 정화 | 2-6 |
| 코드 품질 | SonarQube Cloud — main 대상 PR에 품질 게이트 | 1-3 |
| (10/13) 저장소 3개 | `gotgan-backend`(services · serverless · docker-compose · docs/api) · `gotgan-frontend`(React 루트) · `gotgan-config`(deploy · infra/terraform · scripts · docs). 모노레포 폐지. 각 저장소 `docs/CONVENTION.md`는 이 문서의 발췌본(자동 생성) — 이 문서만 고친다 | 1-4 · 5-5 |
| (10/13) 시크릿 | **GitHub Secrets 단일 소스**(클러스터 · CI) · Vercel 환경 변수(프론트). Secrets Manager · KMS · ESO 없음. `secrets-sync` 워크플로가 K8s Secret 생성 | 1-5 · 5-3 |
| (10/13) 인프라 일일 스케줄 | `infra/terraform/cluster/`는 `infra-schedule` 워크플로가 매일 KST 08:00 apply(→ `bootstrap`) · 22:00 destroy. 나머지 폴더는 상시. apply/destroy는 워크플로 또는 구지훈 | 5-2 |
| (10/13) Redis 폴백 | 장바구니 원본은 MySQL `orderdb.cart_item`, Redis `cart:{userId}`는 캐시. Redis 호출은 서킷 인스턴스 `redisCart` + 폴백(MySQL) | 2-2 · 2-7 · 3-2 |

---

---

## 1. 공통 — Git · 협업

### 1-1. 브랜치

- `main` — 보호 브랜치. 직접 push 금지, PR + 승인 1명 + CI 통과 후 Squash merge
- 작업 브랜치: `feat/{도메인}-{작업}` (예: `feat/order-payment-verify`, `feat/infra-eks-cluster`)
- 그 외: `fix/` · `refactor/` · `docs/` · `chore/`(빌드 · 설정)
- 도메인 값: `auth` `user` `store` `product` `order` `payment` `review` `settlement` `admin` `gateway` `front`(프론트 공통) `infra`(Keycloak 설정 포함, 예: `feat/infra-keycloak-realm`) `cicd` `obs`(관측성) `sls`(서버리스)

### 1-2. 커밋 메시지

- Conventional Commits: `{type}({scope}): {요약}`
- type: `feat` `fix` `refactor` `docs` `test` `chore` `ci` `infra`
- scope: 서비스 · 영역 이름 (`order` `gateway` `front` `terraform` `helm` …)
- 요약은 한국어 명사형 종결, 50자 이내
- 예: `feat(order): 포트원 결제 검증 API` · `fix(front): 장바구니 무료배송 금액 계산` · `infra(terraform): NLB용 EIP 추가`

### 1-3. 이슈 · PR

- 이슈 제목: `[요구사항 ID] 작업` — 예: `[ORD-06] 결제 검증`
- PR 제목: 커밋 메시지 형식과 동일
- PR 본문 템플릿:
  - 개요 — 관련 요구사항 ID · 이슈 링크
  - 작업 내용 — 변경 사항 개조식
  - 테스트 — 확인 방법 (curl · 화면 · 테스트 코드)
  - 팀원 확인 사항 — 다른 팀원이 알아야 할 것
- **프론트 · 다른 서비스에 영향 있는 변경(응답 형식 · 에러 코드 · 이벤트 payload · API 경로)은 PR 제목에 `[영향]` 표시**, 영향받는 담당자 리뷰 필수
- PR 하나에 기능 하나, 변경 300줄 이하 권장
- main 대상 PR은 CI에서 **SonarQube Cloud 품질 게이트**를 통과해야 머지 (이슈는 PR 코멘트로 확인)

### 1-4. 폴더 소유권

- **다른 사람이 맡은 서비스 · `features/` 폴더는 PR 없이 수정 금지.** 연동이 필요하면 이슈로 요청
- 공유 파일(frontend `shared/api/queryKeys.js` · `app/router.jsx`, gotgan-config `deploy/k8s/01-configmap.yaml` · `deploy/helm/sesac-gojigi-app/values.yaml`)은 **도메인별 주석 구획 안에서만** 수정. `values.yaml`의 `tag` 줄은 backend CI만 커밋
- CODEOWNERS로 리뷰어 자동 지정

### 1-5. 시크릿

- `application.yml` · `.env` · YAML에 실제 비밀 값 커밋 금지 — `${환경변수}` 자리표시자만
- 비밀 값 위치: **GitHub Secrets**(클러스터 · CI — gotgan-config · gotgan-backend) · Vercel 환경 변수(프론트). Secrets Manager · KMS · ESO는 쓰지 않음
- 클러스터 시크릿은 gotgan-config의 `secrets-sync` 워크플로가 GitHub Secrets → K8s Secret으로 생성. Secret YAML 파일을 만들지 않음. 이름 · 용도는 `gotgan-config/docs/secrets.md`(값 없음), 값은 노션(팀 비공개)
- 비밀 아닌 값은 GitHub Variables(`AWS_ACCOUNT_ID` · `AWS_REGION` · `EKS_CLUSTER_NAME` · `DUCKDNS_DOMAIN`)
- 로컬은 `.env.local`(커밋 금지) 또는 docker-compose 기본값(`local-pass`). realm JSON · YAML에는 `${변수}` 자리표시자만
- 실수로 커밋했다면 즉시 팀 공유 → 키 폐기 · 재발급 (히스토리 삭제만으로는 부족)

---

---

## 2. 로그 (백엔드 2-8 발췌)

### 2-8. 로깅

- `@Slf4j` 사용. `System.out.println` · `e.printStackTrace()` 금지
- 레벨
  - `error` — 사람이 봐야 하는 실패, 스택트레이스 포함 (`log.error("포트원 취소 실패 - paymentId={}", paymentId, e)`)
  - `warn` — 처리는 됐지만 주의 (재고 부족, 금액 불일치 감지, 재시도)
  - `info` — 상태 변화 (주문 PAID, Saga 보상 완료, 정산 집계 완료)
  - `debug` — 개발 확인용 (운영 미출력)
- 로그 메시지에 업무 키 포함: `orderNo` · `sagaId` · `paymentId` (MDC 또는 메시지)
- **비밀번호 · 토큰 · 포트원 키 · 카드 정보 · 이메일 · 전화 · 주소는 info 이상에 남기지 않음**
- 형식은 JSON (공통 `logback-spring.xml`), traceId 자동 포함 — 형식 임의 변경 금지

---

## 5. 인프라 · 배포 네이밍

### 5-1. AWS 자원

- 이름: `sesac-gojigi-{용도}` (kebab-case) — `sesac-gojigi-eks-cluster` · `sesac-gojigi-order-events`
- 모든 자원 태그: `Project=sesac-gojigi` · `ManagedBy=terraform` (콘솔에서 만든 자원은 `ManagedBy=manual` + 이슈 기록)
- 계정 ID · 리전 하드코딩 금지 — `data.aws_caller_identity` · 변수 사용

| 자원 | 규칙 | 예 |
|---|---|---|
| SNS 토픽 | `sesac-gojigi-{도메인}-events` | `sesac-gojigi-order-events` |
| SQS 큐 | `sesac-gojigi-{소비자}-{도메인}-events` | `sesac-gojigi-settlement-order-events` |
| DLQ | 큐 이름 + `-dlq` | `sesac-gojigi-settlement-order-events-dlq` |
| IAM 역할 (IRSA) | `sesac-gojigi-{service}-irsa` | `sesac-gojigi-order-irsa` |
| SSM 파라미터 | `/sesac-gojigi/dev/{종류}/{이름}` | `/sesac-gojigi/dev/sqs/notification-queue-arn` |
| S3 버킷 | `sesac-gojigi-{용도}-{계정ID 끝 4자리}` (전역 유일) | `sesac-gojigi-images-1234`(prefix `products/` · `reviews/`) · `sesac-gojigi-seller-docs-1234` · `sesac-gojigi-reports-1234` · `sesac-gojigi-log-archive-1234` |
| DynamoDB | `sesac-gojigi-{용도}` | `sesac-gojigi-notifications` · `sesac-gojigi-settlement-reports` (그 외 테이블 없음) |

### 5-2. Terraform

- 파일: 자원 종류별 snake_case (`sns_sqs.tf` · `irsa.tf`), 폴더마다 `provider.tf` · `variables.tf` · `outputs.tf`
- 자원 로컬 이름: snake_case, 타입 반복 금지 (`aws_s3_bucket.product_images` ○ / `aws_s3_bucket.product_images_bucket` ✗)
- 변수 · output: snake_case + `description` 필수
- 커밋 전 `terraform fmt -recursive` · `terraform validate`
- apply/destroy는 스케줄 워크플로(`infra-schedule`, OIDC 역할 — `cluster/` 매일 08:00 · 22:00) 또는 구지훈. 다른 사람은 plan까지(`infra.yml`이 PR에 plan 코멘트)
- Terraform에 비밀 값 금지 — 시크릿은 GitHub Secrets → `secrets-sync`(1-5). `kms.tf` · `secrets.tf` · `eso.tf` 없음
- `.terraform.lock.hcl` 커밋, `*.tfstate` · `.terraform/` 커밋 금지

### 5-3. Kubernetes · Helm

- 리소스 이름: 서비스 이름 그대로 kebab-case (`order-service`)
- 라벨: `app: {service}` 필수 (Service selector · Prometheus · 로그 라벨 기준)
- 파일 이름: 적용 순서가 있으면 `{nn}-{종류}.yaml` (`00-namespace.yaml`), 그 외 `{대상}.yaml`
- YAML 들여쓰기 2칸, 탭 금지
- 네임스페이스: 앱 `sesac-gojigi` · 모니터링 `monitoring` · `argocd`
- Helm `values.yaml` 키는 camelCase, 서비스 키는 서비스 이름 (`services.order-service.tag`)
- Secret 이름: `mysql-secret` · `{service}-secret` · `keycloak-secret` · `grafana-secret` · `alert-webhook-secret` — 파일로 커밋하지 않고 `secrets-sync` 워크플로가 생성. 서비스는 `envFrom.secretRef`로만 읽음
- Redis는 AOF(`appendonly yes`) + PVC(`ebs-sc` 1Gi)
- 이미지 태그: 커밋 SHA 7자리. `latest` 금지
- 모든 컨테이너에 `resources.requests` 필수, 메모리 `limits` 필수

### 5-4. 환경 변수 · 설정

- 환경 변수: UPPER_SNAKE (`DB_HOST` · `PRODUCT_SERVICE_URI` · `PORTONE_API_SECRET`)
- 다른 서비스 주소: `{대상}_SERVICE_URI`
- `application.yml` 커스텀 키: `app.{영역}.{이름}` kebab-case (`app.order.auto-confirm-after`)
- 프론트: `VITE_{이름}` (`VITE_PORTONE_STORE_ID`)

### 5-5. Serverless · CI

- 함수 폴더: kebab-case — `order-notification` · `settlement-report` · `log-archive` (3개, 사용자 API 없음), 서비스 이름 `sesac-gojigi-{폴더명}`
- 핸들러 파일 camelCase (`notify.js`), export 이름 `handler`
- 워크플로 파일: 영역 이름 kebab-case, job 이름 kebab-case (`bump-tag`). 저장소별 — gotgan-backend `backend.yml` · `serverless.yml` · `security.yml` / gotgan-frontend `frontend.yml` · `security.yml` / gotgan-config `infra.yml` · `infra-schedule.yml` · `bootstrap.yml` · `secrets-sync.yml` · `security.yml`
- GitHub Secrets: UPPER_SNAKE (`AWS_ROLE_ARN` · `SERVERLESS_ACCESS_KEY` · `CONFIG_REPO_TOKEN` · `{SERVICE}_DB_PASSWORD`), Variables도 UPPER_SNAKE (`AWS_REGION`)
- 저장소 간 토큰 `CONFIG_REPO_TOKEN`: fine-grained PAT, gotgan-config만 · Contents write만, 만료일은 발표(11/20) 이후

---

