# Keycloak (담당 이경석)

- `realm-gotgan.json`: 콘솔에서 export 한 realm 을 커밋하되 **gotgan-backend 의 client secret 값은 넣지 않는다**. JSON 에는 자리표시자 `"secret": "${GOTGAN_BACKEND_CLIENT_SECRET}"` 만 있고, Keycloak 이 `--import-realm` 할 때 같은 이름의 환경 변수로 치환한다. 그 환경 변수는 K8s Secret `keycloak-secret`(envFrom) 에서 오고, `keycloak-secret` 은 GitHub Secret `KEYCLOAK_CLIENT_SECRET` 을 `secrets-sync` 워크플로가 만든다. user-service 는 같은 값을 `user-service-secret` 의 `KEYCLOAK_CLIENT_SECRET` 으로 받는다 (목록: `docs/secrets.md`).
- 시연 계정(ADMIN 포함)은 JSON 이 아니라 `scripts/keycloak-seed.sh` 로 만든다 (비밀 값 커밋 금지 — 아래 "시드 계정"). 클러스터는 매일 빈 DB 에서 다시 뜨므로 realm import + 시드 스크립트가 매일 실행된다.
- 클러스터: `bootstrap` 워크플로가 `kubectl create configmap keycloak-realm --from-file=realm-gotgan.json` → `keycloak.yaml` 적용. 관리 콘솔은 `kubectl port-forward svc/keycloak 8180:8080 -n sesac-gojigi`
- 로컬: docker compose 가 `start-dev --import-realm` 으로 같은 파일을 읽는다 → http://localhost:8180 (admin / admin). `GOTGAN_BACKEND_CLIENT_SECRET` 은 compose 기본값(`local-client-secret`) 으로 치환된다
- ⚠️ `--import-realm` 은 **realm 이 이미 있으면 건너뛴다**. JSON 을 바꾼 뒤 로컬에 반영하려면 keycloakdb 를 비우거나(compose 볼륨 삭제) 콘솔에서 realm 을 지우고 재기동. 클러스터는 매일 새 DB 라 다음 생성 때 자동 반영

## realm `gotgan` 설정 (가이드라인 08장)

| 항목 | 값 |
| --- | --- |
| 로그인 ID | 이메일 = username (`registrationEmailAsUsername`), 이메일 중복 금지, username 변경 금지 |
| 토큰 · 세션 | Access Token 30분 · SSO Session Idle / Max 14일(= Refresh 수명) · **Refresh Token 로테이션**(`revokeRefreshToken`, 재사용 0회) |
| 비밀번호 정책 | 8자 이상 · 영문 1자 이상 · 특수문자 1자 이상 · username(이메일)과 다름 |
| Brute Force | 연속 5회 실패 시 임시 잠금 (1분부터 늘어나 최대 15분, 영구 잠금 없음) |
| Realm 역할 | `BUYER`(기본 역할 `default-roles-gotgan` 에 포함 → 새 사용자 자동 부여) · `SELLER`(입점 승인 시 user-service 가 추가) · `ADMIN`(시드로만) |
| User Profile | `user_id` · `store_id` 선언 — **관리자만 보기 · 편집** (Keycloak 24+ 는 선언 안 된 속성을 저장하지 않음). 이름(firstName · lastName)은 선택값 — 주인은 userdb |
| 클라이언트 `gotgan-backend` | confidential · Direct Access Grants 켬 · Standard Flow 끔 · 서비스 계정 켬 |
| 서비스 계정 권한 | `realm-management` 의 `manage-users` · `view-realm` — 가입(계정 생성) · SELLER 부여 · 이용정지(enabled) · store_id 저장 |
| Access Token 클레임 | `user_id`(long) · `store_id`(long, 판매자만) · `roles`(realm 역할 목록) |

### 검증 (Keycloak 26.8, 2026-10-19)

같은 버전 임시 컨테이너에 import 후 확인:

1. 서비스 계정 토큰(client_credentials) 발급
2. 비밀번호 정책 위반(`abcdefgh` · `1234567!` · `ab!1`) → 400, `Passw0rd!` → 201
3. 서비스 계정으로 사용자 생성 + `user_id` 속성 저장
4. 이메일 · 비밀번호 Direct Grant 로그인 → Access Token `user_id=101`(숫자) · `roles` 에 `BUYER` · 수명 1800초
5. Refresh 1회 성공 · 이전 Refresh Token 재사용 → `invalid_grant`
6. `SELLER` 부여 + `store_id` 저장 후 로그인 → `roles` 에 `SELLER` · `store_id=55`
7. `enabled=false` → 로그인 `Account disabled`
8. 연속 실패 후 올바른 비밀번호도 거부 (임시 잠금)

## 시드 계정 — `scripts/keycloak-seed.sh`

| 이메일 | 역할 (BUYER 는 기본 역할) | `user_id` | `store_id` | 비밀번호 |
| --- | --- | --- | --- | --- |
| `admin@gotgan.com` | ADMIN | 1 | – | `SEED_ADMIN_PASSWORD` |
| `seller1@gotgan.com` | SELLER | 2 | 1 | `SEED_DEMO_PASSWORD` |
| `seller2@gotgan.com` | SELLER | 3 | 2 | `SEED_DEMO_PASSWORD` |
| `buyer1@gotgan.com` | – | 4 | – | `SEED_DEMO_PASSWORD` |
| `buyer2@gotgan.com` | – | 5 | – | `SEED_DEMO_PASSWORD` |
| `buyer3@gotgan.com` | – | 6 | – | `SEED_DEMO_PASSWORD` |

- **`user_id` · `store_id` 는 userdb · storedb 의 `R__demo_seed.sql` 과 같은 값이어야 한다** — gateway 가 토큰 `user_id` 로 `X-User-Id` 를 만든다 (userdb 시드: 이경석, storedb 시드: store 담당)
- 실행: bootstrap 3-1 단계 `kubectl exec -i -n sesac-gojigi deploy/keycloak -- bash -s < scripts/keycloak-seed.sh` — 파드 안 `kcadm.sh` 와 환경 변수(`keycloak-secret`)를 쓴다. 로컬은 `docker compose exec -T keycloak bash -s < ../gotgan-config/scripts/keycloak-seed.sh`
- 비밀번호: GitHub Secret `SEED_ADMIN_PASSWORD` · `SEED_DEMO_PASSWORD` → secrets-sync → `keycloak-secret`. 비어 있으면 시드를 건너뛴다 (bootstrap 실패 아님). 비밀번호 정책(8자 · 영문 · 특수문자)을 지켜야 한다
- 멱등: 이미 있는 계정은 비밀번호를 건드리지 않고 속성 · 역할만 맞춘다 — bootstrap 을 다시 돌려도 안전
- 이미 떠 있는 클러스터에 시크릿을 새로 넣었다면 Keycloak 파드 환경 변수 갱신이 필요 (`kubectl rollout restart deployment/keycloak -n sesac-gojigi`). 매일 생성되는 클러스터는 secrets-sync 가 먼저 돌아 자동 반영
- 검증 (Keycloak 26.8 임시 컨테이너, 2026-10-19): 1회차 6개 생성 · 2회차 전부 "이미 있음" · 시드 비밀번호 없으면 건너뜀 · 6개 계정 로그인 토큰의 `user_id` · `store_id` · 역할 확인

## 소셜 로그인 (카카오 · 네이버 · 구글) — 준비 전, 추가 시 고려사항

현재 realm 은 자체 계정(이메일 · 비밀번호, Direct Grant)만 쓴다 — `identityProviders` 없음, Standard Flow 끔. 소셜은 아래를 **추가**하는 방식이라 지금 구조(토큰 클레임 · gateway · 다른 서비스 · 쿠키 방식)는 바뀌지 않는다.

| 영역 | 추가 작업 |
| --- | --- |
| Keycloak realm | Identity Provider 3개 등록(구글 기본 제공, 카카오 · 네이버는 OIDC 설정 또는 확장) · 소셜 경로용 Standard Flow(리다이렉트) |
| user-service | 소셜 시작 · 콜백 API — 콜백에서 code → 토큰 교환 후 지금과 같이 RT 쿠키 · AT body |
| 프론트 | 소셜 버튼 · 콜백 페이지 (로그인 이후 흐름은 동일) |
| 시크릿 | 제공자별 client ID · secret 3쌍 (GitHub Secrets → Keycloak) |

미리 정할 것:

1. **첫 소셜 로그인 때 `user_id` 채우기** — Keycloak 이 계정을 먼저 만들어 첫 토큰에 `user_id` 가 없다(gateway 401). 콜백에서 user-service 가 `users` 행 생성(`User.fromSocialLogin`) → Keycloak 속성 `user_id` 저장 → 토큰 재발급
2. **이메일 없는 소셜 계정** — 현재 이메일 = username, userdb `email` NOT NULL. 카카오는 이메일이 선택 동의라 비어 올 수 있음 → 이메일 동의 필수(카카오 비즈 앱) / 추가 입력 / 필수 완화 중 결정
3. **같은 이메일의 자체 계정과 소셜 계정** — 자동 연결 · 확인 후 연결 · 별도 계정 중 결정 (Keycloak First Broker Login 흐름)
4. 비밀번호 정책 · Brute Force 는 소셜 계정에 적용되지 않음 (제공자가 인증)
