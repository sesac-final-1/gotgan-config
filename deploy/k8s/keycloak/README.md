# Keycloak (담당 이경석)

- `realm-gotgan.json`: 콘솔에서 export 한 realm 을 커밋하되 **gotgan-backend 의 client secret 값은 넣지 않는다**. JSON 에는 자리표시자 `"secret": "${GOTGAN_BACKEND_CLIENT_SECRET}"` 만 있고, Keycloak 이 `--import-realm` 할 때 같은 이름의 환경 변수로 치환한다. 그 환경 변수는 K8s Secret `keycloak-secret`(envFrom) 에서 오고, `keycloak-secret` 은 GitHub Secret `KEYCLOAK_CLIENT_SECRET` 을 `secrets-sync` 워크플로가 만든다. user-service 는 같은 값을 `user-service-secret` 의 `KEYCLOAK_CLIENT_SECRET` 으로 받는다 (목록: `docs/secrets.md`).
- 사용자 속성 `user_id` · `store_id` 는 Realm settings → User profile 에 선언해야 Admin API 로 저장된다 (뼈대 JSON 에는 매퍼만 있음).
- 서비스 계정(gotgan-backend) 에 `manage-users` (+ `view-realm`) 역할 부여 — 가입 · 역할 부여 · store_id 저장용.
- ADMIN 시드 계정은 JSON 이 아니라 Admin API · 시드 스크립트로 만든다 (비밀 값 커밋 금지). 클러스터는 매일 08:00 빈 DB 에서 다시 뜨므로 realm import + 시드 스크립트가 매일 실행된다.
- 클러스터: `bootstrap` 워크플로가 `kubectl create configmap keycloak-realm --from-file=realm-gotgan.json` → `keycloak.yaml` 적용. 관리 콘솔은 `kubectl port-forward svc/keycloak 8180:8080 -n sesac-gojigi`
- 로컬: docker compose 가 `start-dev --import-realm` 으로 같은 파일을 읽는다 → http://localhost:8180 (admin / admin). `GOTGAN_BACKEND_CLIENT_SECRET` 은 compose 기본값(`local-client-secret`) 으로 치환된다
