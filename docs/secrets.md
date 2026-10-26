# 시크릿 · 변수 목록 (GitHub Secrets 단일 소스)

> **이 파일에는 값이 없습니다.** 실제 값은 노션(팀 비공개 페이지 "곳간 시크릿")에만 둡니다. 코드 · YAML · 로그 · Git 히스토리 어디에도 값을 쓰지 않습니다(컨벤션 1-5).
> 등록 위치: GitHub → 저장소 → Settings → Secrets and variables → Actions. 클러스터용 시크릿은 `secrets-sync` 워크플로가 GitHub Secrets를 읽어 K8s Secret으로 만듭니다(매일 08:00 bootstrap에 포함).

## 1. gotgan-config (인프라 · 클러스터) — Secrets

| 이름 | 쓰는 곳 | K8s Secret → 키 | 생성 방법 | 담당 |
|---|---|---|---|---|
| `AWS_ROLE_ARN` | infra · infra-schedule · bootstrap · secrets-sync (OIDC) | — | Terraform `cicd/` output (`arn:aws:iam::<계정>:role/sesac-gojigi-github-actions`) | 이경석 |
| `MYSQL_ROOT_PASSWORD` | MySQL StatefulSet · init-schemas.sh | `mysql-secret` → `MYSQL_ROOT_PASSWORD` | 무작위 24자 (`openssl rand -base64 24`) | 구지훈 |
| `USER_DB_PASSWORD` | init-schemas.sh · user-service | `mysql-secret` + `user-service-secret` → `DB_PASSWORD` | 무작위 24자 | 구지훈 |
| `STORE_DB_PASSWORD` | 〃 store | `mysql-secret` + `store-service-secret` | 〃 | 구지훈 |
| `PRODUCT_DB_PASSWORD` | 〃 product | `mysql-secret` + `product-service-secret` | 〃 | 구지훈 |
| `ORDER_DB_PASSWORD` | 〃 order | `mysql-secret` + `order-service-secret` | 〃 | 구지훈 |
| `PAYMENT_DB_PASSWORD` | 〃 payment | `mysql-secret` + `payment-service-secret` | 〃 | 구지훈 |
| `REVIEW_DB_PASSWORD` | 〃 review | `mysql-secret` + `review-service-secret` | 〃 | 구지훈 |
| `SETTLEMENT_DB_PASSWORD` | 〃 settlement | `mysql-secret` + `settlement-service-secret` | 〃 | 구지훈 |
| `ADMIN_DB_PASSWORD` | 〃 admin — admindb(신고 · 조치 이력, ADR-0001 예외 10/26) | `mysql-secret` + `admin-service-secret` | 〃 | 구지훈 |
| `KEYCLOAK_DB_PASSWORD` | init-schemas.sh · Keycloak | `mysql-secret` + `keycloak-secret` → `KC_DB_PASSWORD` | 〃 | 구지훈 |
| `KEYCLOAK_ADMIN_USERNAME` | Keycloak 초기 관리자 | `keycloak-secret` → `KC_BOOTSTRAP_ADMIN_USERNAME` | 팀이 정함 (예: `gotgan-admin`) | 이경석 |
| `KEYCLOAK_ADMIN_PASSWORD` | 〃 | `keycloak-secret` → `KC_BOOTSTRAP_ADMIN_PASSWORD` | 무작위 24자 | 이경석 |
| `KEYCLOAK_CLIENT_SECRET` | `gotgan-backend` 클라이언트 (realm import 자리표시자 `${GOTGAN_BACKEND_CLIENT_SECRET}`) · user-service | `keycloak-secret` → `GOTGAN_BACKEND_CLIENT_SECRET`, `user-service-secret` → `KEYCLOAK_CLIENT_SECRET` | 무작위 32자 | 이경석 |
| `SEED_ADMIN_PASSWORD` | Keycloak 시드 — 곳간 관리자 `wlsgksvheh+admin@gmail.com` (ADMIN) 비밀번호 · `scripts/keycloak-seed.sh` (bootstrap 3-1) | `keycloak-secret` → `SEED_ADMIN_PASSWORD` | 팀이 정함 — 비밀번호 정책: 8자 이상 · 영문 · 특수문자 (없으면 시드 건너뜀) | 이경석 |
| `SEED_DEMO_PASSWORD` | Keycloak 시드 — 시연 계정 `wlsgksvheh+seller1·2` · `wlsgksvheh+buyer1·2·3@gmail.com` 공용 비밀번호 | `keycloak-secret` → `SEED_DEMO_PASSWORD` | 〃 | 이경석 |
| `GOOGLE_CLIENT_ID` · `GOOGLE_CLIENT_SECRET` | 소셜 로그인 — realm IdP `google` 자리표시자 | `keycloak-secret` → 같은 이름 (realm import 때 치환) | Google Cloud 콘솔 → API 및 서비스 → 사용자 인증 정보 → OAuth 클라이언트 ID (keycloak README 소셜 로그인) | 이경석 |
| `KAKAO_CLIENT_ID` · `KAKAO_CLIENT_SECRET` | 소셜 로그인 — realm IdP `kakao` (OIDC) | 〃 | Kakao Developers → 앱 키(REST API 키) · 카카오 로그인 → 보안(Client Secret) | 이경석 |
| `NAVER_CLIENT_ID` · `NAVER_CLIENT_SECRET` | 소셜 로그인 — realm IdP `naver` (OAuth 2.0) | 〃 | NAVER Developers → 애플리케이션 → Client ID · Client Secret | 이경석 |
| `PORTONE_API_SECRET` | payment-service (포트원 V2 API) | `payment-service-secret` → `PORTONE_API_SECRET` | 포트원 콘솔 → 결제 연동 → API Secret (테스트 채널) | 구지훈 |
| `PORTONE_WEBHOOK_SECRET` | payment-service 웹훅 서명 검증 | `payment-service-secret` → `PORTONE_WEBHOOK_SECRET` | 포트원 콘솔 → 웹훅 설정 | 구지훈 |
| `GRAFANA_ADMIN_PASSWORD` | Grafana 로그인 | `grafana-secret`(monitoring) → `admin-password` | 무작위 24자 | 박지연 |
| `ALERT_WEBHOOK_URL` | Grafana Alerting → Discord/Slack | `alert-webhook-secret`(monitoring) → `url` | Discord 채널 → 연동 → 웹훅 URL | 박지연 |

## 2. gotgan-backend (CI) — Secrets

| 이름 | 쓰는 곳 | 생성 방법 | 담당 |
|---|---|---|---|
| `AWS_ROLE_ARN` | backend.yml(ECR push) · serverless.yml(Lambda 배포) | config와 같은 역할 ARN (Terraform `cicd/`) | 이경석 |
| `SONAR_TOKEN` | backend.yml `./gradlew sonar` (PR → main) | SonarQube Cloud → My Account → Security → Generate token | 구지훈 |
| `SERVERLESS_ACCESS_KEY` | serverless.yml (`serverless deploy`) | app.serverless.com → Org → Access keys | 구지훈 |
| `CONFIG_REPO_TOKEN` | backend.yml `bump-tag` — gotgan-config `values.yaml` 태그 커밋 | GitHub → Settings → Developer settings → **Fine-grained token**: 저장소 `sesac-final-1/gotgan-config`만, 권한 Contents: Read and write, 만료 2026-11-30 | 이경석 |

## 3. gotgan-frontend — Vercel 환경 변수 (GitHub Secrets 아님)

| 이름 | 용도 | 출처 | 담당 |
|---|---|---|---|
| `VITE_PORTONE_STORE_ID` | 포트원 브라우저 SDK | 포트원 콘솔 → 상점 ID | 구지훈 |
| `VITE_PORTONE_CHANNEL_KEY` | 〃 테스트 채널 키 | 포트원 콘솔 → 결제 연동 → 채널 키 | 구지훈 |
| `VITE_GRAFANA_URL` | 관리자 화면의 System Status 링크 | port-forward 주소 또는 Grafana 주소 | 박지연 |

비밀이 아니므로 `.env.example`에 이름만 커밋, 값은 Vercel → Project → Settings → Environment Variables.

## 4. GitHub Variables (비밀 아님, 두 저장소 공통)

| 이름 | 값 예 | 쓰는 곳 |
|---|---|---|
| `AWS_ACCOUNT_ID` | 12자리 계정 ID | ECR 주소 · IRSA ARN |
| `AWS_REGION` | `ap-northeast-2` | 모든 워크플로 |
| `EKS_CLUSTER_NAME` | `sesac-gojigi-eks-cluster` | bootstrap · secrets-sync · destroy |

## 5. 로컬 개발 (커밋 금지)

- docker-compose 기본값(`local-pass` · admin/admin · `local-client-secret`)은 로컬 전용. 클러스터 값과 다름
- 포트원 키처럼 로컬에서도 실제 값이 필요한 것은 `.env.local`(gitignore) 또는 IDE 환경 변수로

## 6. 운영 규칙

- 값을 바꾸면 노션 갱신 → GitHub Secret 갱신 → `secrets-sync` 수동 실행(또는 다음 날 08:00 bootstrap) → 해당 Deployment `rollout restart`
- 실수로 커밋했다면 즉시 팀 공유 → 키 폐기 · 재발급(히스토리 삭제만으로는 부족, 컨벤션 1-5)
- `CONFIG_REPO_TOKEN`은 만료일이 있음 — 만료 전 재발급 (19장 위험 요소)

## 7. 예외 — AWS SSM SecureString (1건, 10/26 팀 결정)

GitHub Secrets 는 GitHub 안에서만 읽을 수 있어, **AWS 에서 GitHub 를 부르는** 스케줄러 Lambda 의 토큰만 AWS 에 둡니다.

| 이름 | 쓰는 곳 | 생성 방법 | 담당 |
|---|---|---|---|
| SSM `/sesac-gojigi/dev/github/infra-dispatch-token` (SecureString, AWS 관리형 키 `aws/ssm`) | Lambda `sesac-gojigi-infra-dispatch` — 매일 08:00 · 22:00 `infra-schedule` workflow_dispatch (`infra/terraform/app/scheduler.tf`) | GitHub fine-grained PAT — 저장소 `gotgan-config` 만 · 권한 **Actions: Read and write**(Metadata 읽기 자동). 만료일을 정하고 노션에 기록 | 구지훈 |

- Terraform 은 이 파라미터를 **만들지 않습니다**(값이 상태 파일에 남지 않게). 등록 · 교체는 CLI 로 직접:
  `aws ssm put-parameter --name /sesac-gojigi/dev/github/infra-dispatch-token --type SecureString --overwrite --value "<토큰>"` (값은 셸 기록에 남지 않게 직접 입력)
- 만료 · 폐기되면 08:00 · 22:00 실행이 실패합니다 → Lambda 로그(`/aws/lambda/sesac-gojigi-infra-dispatch`)에 `GitHub dispatch 실패 401` — 재발급 후 위 명령으로 교체
