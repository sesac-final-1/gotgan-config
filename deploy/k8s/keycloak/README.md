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
| `wlsgksvheh+admin@gmail.com` | ADMIN | 1 | – | `SEED_ADMIN_PASSWORD` |
| `wlsgksvheh+seller1@gmail.com` | SELLER | 2 | 1 | `SEED_DEMO_PASSWORD` |
| `wlsgksvheh+seller2@gmail.com` | SELLER | 3 | 2 | `SEED_DEMO_PASSWORD` |
| `wlsgksvheh+buyer1@gmail.com` | – | 4 | – | `SEED_DEMO_PASSWORD` |
| `wlsgksvheh+buyer2@gmail.com` | – | 5 | – | `SEED_DEMO_PASSWORD` |
| `wlsgksvheh+buyer3@gmail.com` | – | 6 | – | `SEED_DEMO_PASSWORD` |

- **`user_id` · `store_id` 는 userdb · storedb 의 `R__demo_seed.sql` 과 같은 값이어야 한다** — gateway 가 토큰 `user_id` 로 `X-User-Id` 를 만든다 (userdb 시드: 이경석, storedb 시드: store 담당)
- 실행: bootstrap 3-1 단계 `kubectl exec -i -n sesac-gojigi deploy/keycloak -- bash -s < scripts/keycloak-seed.sh` — 파드 안 `kcadm.sh` 와 환경 변수(`keycloak-secret`)를 쓴다. 로컬은 `docker compose exec -T keycloak bash -s < ../gotgan-config/scripts/keycloak-seed.sh`
- 비밀번호: GitHub Secret `SEED_ADMIN_PASSWORD` · `SEED_DEMO_PASSWORD` → secrets-sync → `keycloak-secret`. 비어 있으면 시드를 건너뛴다 (bootstrap 실패 아님). 비밀번호 정책(8자 · 영문 · 특수문자)을 지켜야 한다
- 멱등: 이미 있는 계정은 비밀번호를 건드리지 않고 속성 · 역할만 맞춘다 — bootstrap 을 다시 돌려도 안전
- 이미 떠 있는 클러스터에 시크릿을 새로 넣었다면 Keycloak 파드 환경 변수 갱신이 필요 (`kubectl rollout restart deployment/keycloak -n sesac-gojigi`). 매일 생성되는 클러스터는 secrets-sync 가 먼저 돌아 자동 반영
- 검증 (Keycloak 26.8 임시 컨테이너, 2026-10-19): 1회차 6개 생성 · 2회차 전부 "이미 있음" · 시드 비밀번호 없으면 건너뜀 · 6개 계정 로그인 토큰의 `user_id` · `store_id` · 역할 확인

## 소셜 로그인 (카카오 · 네이버 · 구글)

user-service 가 대리(BFF)로 처리한다 — 브라우저는 Keycloak 로그인 · 제공자 화면만 직접 거치고, 토큰은 user-service 가 받는다.
로그인 이후(토큰 클레임 `user_id` · `roles`, gateway, Refresh 쿠키)는 자체 로그인과 같다.

```
프론트 → GET /api/auth/social/{google|kakao|naver}            (user-service — state · PKCE 쿠키, 302)
       → https://api.gotgan.click/realms/gotgan/protocol/openid-connect/auth?kc_idp_hint=…   (gateway → Keycloak)
       → 제공자 로그인 → https://api.gotgan.click/realms/gotgan/broker/{alias}/endpoint
       → (첫 로그인: 같은 이메일 자체 계정이면 비밀번호 확인 후 연결 · 이메일 없으면 입력 화면)
       → https://gotgan-ashy.vercel.app/api/auth/social/callback?code=…   (vercel 리라이트 → gateway → user-service)
            code → 토큰(PKCE) · 첫 소셜 로그인이면 users 행 생성 → Keycloak user_id 저장 → 토큰 재발급
       → Refresh 쿠키 + 302 https://gotgan-ashy.vercel.app/auth/callback   (실패면 ?error=코드)
프론트 /auth/callback → POST /api/auth/refresh 로 Access Token
```

| 항목 | 설정 |
| --- | --- |
| 공개 주소 | `KC_HOSTNAME=https://api.gotgan.click` — 로그인 화면 · 토큰 `iss`. gateway 가 `/realms/gotgan/**` · `/resources/**` 만 Keycloak 으로 보낸다 (관리 콘솔 · master realm 은 열지 않음) |
| 서버 간 호출 | `KC_HOSTNAME_BACKCHANNEL_DYNAMIC=true` — user-service 토큰 · Admin API, gateway JWKS 는 내부 `http://keycloak:8080` 그대로 |
| 관리 콘솔 | `KC_HOSTNAME_ADMIN=http://localhost:8080` — `kubectl port-forward svc/keycloak 8080:8080` 후 `http://localhost:8080/admin` (keycloak:8080 hosts 우회 불필요) |
| gateway 검증 | `KEYCLOAK_ISSUER=https://api.gotgan.click/realms/gotgan` (iss) · `jwk-set-uri` 는 내부 주소 — **KC_HOSTNAME 과 같은 날 배포** (한쪽만 바뀌면 모든 토큰 401) |
| 클라이언트 `gotgan-backend` | Standard Flow 켬 · PKCE S256 필수 · redirectUris = 프론트 콜백 · localhost(개발) |
| IdP `google` | Keycloak 기본 제공자 |
| IdP `kakao` | OIDC (`kauth.kakao.com`) · 닉네임 → firstName 매퍼 · scope `openid account_email profile_nickname` |
| IdP `naver` | 범용 OAuth 2.0 (Keycloak 26.8 `oauth2`) · userinfo 가 `{"response":{...}}` 라 `userIDClaim=response.id` · `emailClaim=response.email` · `fullNameClaim=response.name` |
| client ID · secret | realm JSON `${GOOGLE_CLIENT_ID:unset}` 등 자리표시자 → `keycloak-secret` (GitHub Secrets → secrets-sync). 비어 있으면 그 제공자만 로그인 실패 |
| 첫 로그인 흐름 | 기본 `first broker login` — 같은 이메일 자체 계정은 **비밀번호 확인 후 연결**, 이메일 없는 카카오 계정은 **입력 화면**(Review Profile) |

결정 (2026-10-21): ① 같은 이메일은 비밀번호 확인 후 연결 ② 카카오 이메일이 없으면 Keycloak 화면에서 입력 ③ 탈퇴한 이메일은 소셜로도 재가입 불가(`?error=AUTH_EMAIL_DUPLICATE`) ④ 가입 경로(`signup_provider`)는 처음 만든 경로 — 자체 계정에 소셜을 연결해도 LOCAL 유지

### 검증 (Keycloak 26.8.1 + gateway + user-service, 가짜 카카오 OIDC · 네이버 OAuth2, 2026-10-21)

카카오 첫 로그인(회원 생성 · user_id 저장 · 재발급 토큰 user_id) · 재로그인(새 행 없음) · 네이버(중첩 userinfo) · 이메일 없는 카카오(입력 화면) · 자체 계정 이메일(비밀번호 확인 후 연결, 기존 user_id) · state 위조(`?error=AUTH_SOCIAL_LOGIN_FAILED`) · 토큰 `iss` 공개 주소로 gateway 검증 · `/admin` · `/realms/master` 비공개 · 바뀐 hostname 에서 시드 스크립트 동작. 구글은 실제 키가 있어야 해서 realm import(자리표시자 치환)까지만 확인

### 제공자 개발자 콘솔 등록 (이경석)

세 곳 모두 **리다이렉트(콜백) URI 는 Keycloak broker 주소**다 — 우리 user-service 주소가 아니다.

| 제공자 | 등록 | 리다이렉트 URI | GitHub Secrets |
| --- | --- | --- | --- |
| 구글 | Google Cloud 콘솔 → OAuth 동의 화면(외부, 테스트 사용자 등록 또는 게시) → 사용자 인증 정보 → OAuth 클라이언트 ID(웹 애플리케이션) | `https://api.gotgan.click/realms/gotgan/broker/google/endpoint` | `GOOGLE_CLIENT_ID` · `GOOGLE_CLIENT_SECRET` |
| 카카오 | Kakao Developers → 애플리케이션 추가 → 카카오 로그인 활성화 · **OpenID Connect 활성화** · 동의항목(닉네임 필수, 카카오계정(이메일) 선택) · 보안 → Client Secret 생성 · 사용 | `https://api.gotgan.click/realms/gotgan/broker/kakao/endpoint` | `KAKAO_CLIENT_ID`(REST API 키) · `KAKAO_CLIENT_SECRET` |
| 네이버 | NAVER Developers → 애플리케이션 등록 → 네이버 로그인 · 제공 정보(이메일 · 이름 필수) · 서비스 URL `https://gotgan-ashy.vercel.app` · 개발 중이면 멤버 관리에 테스트 아이디 등록 | `https://api.gotgan.click/realms/gotgan/broker/naver/endpoint` | `NAVER_CLIENT_ID` · `NAVER_CLIENT_SECRET` |

등록 후: GitHub Secrets 6개 → 다음 bootstrap(매일 07:00)에 secrets-sync · realm import 로 반영. 이미 떠 있는 클러스터면 secrets-sync 수동 실행 후 realm 을 다시 import 해야 한다 (realm 이 있으면 import 를 건너뜀).

미리 알아둘 것:

- 이메일 없는 카카오 계정 — 입력한 이메일은 인증하지 않는다 (SMTP 없음). 이메일 필수 동의는 카카오 비즈 앱 심사 필요
- 비밀번호 정책 · Brute Force 는 소셜 계정에 적용되지 않음 (제공자가 인증)
- 소셜 계정은 `users.phone` 이 비어 있다 — 주문 전 입력 받기 (order 담당)
