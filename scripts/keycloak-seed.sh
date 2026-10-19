#!/bin/bash
# Keycloak 시연 계정 시드 — realm gotgan 에 관리자 · 판매자 · 구매자 계정을 만든다. 담당 이경석 · 가이드라인 08장 · 12장
# 클러스터는 매일 빈 keycloakdb 에서 시작하므로 bootstrap 이 매일 실행한다 (realm 설정은 realm-gotgan.json import, 사용자는 이 스크립트)
#
# Keycloak 파드 안에서 실행된다 — 파일을 표준 입력으로 넘기면 파드의 kcadm.sh 와 환경 변수(keycloak-secret)를 그대로 쓴다:
#   클러스터: kubectl exec -i -n sesac-gojigi deploy/keycloak -- bash -s < scripts/keycloak-seed.sh   (bootstrap 워크플로)
#   로컬:     docker compose exec -T keycloak bash -s < ../gotgan-config/scripts/keycloak-seed.sh
# 필요한 환경 변수 (keycloak-secret · compose):
#   KC_BOOTSTRAP_ADMIN_USERNAME · KC_BOOTSTRAP_ADMIN_PASSWORD — master 콘솔 admin (kcadm 로그인)
#   SEED_ADMIN_PASSWORD — 곳간 관리자 계정 비밀번호 · SEED_DEMO_PASSWORD — 판매자 · 구매자 공용 비밀번호
#   (비밀번호 정책: 8자 이상 · 영문 · 특수문자 — realm-gotgan.json passwordPolicy)
#
# 멱등 — 이미 있는 계정은 비밀번호를 건드리지 않고 속성 · 역할만 맞춘다. 실패하면 bootstrap 을 다시 실행해도 된다
# user_id · store_id 는 userdb · storedb 의 R__demo_seed.sql 과 같은 값이어야 한다 (gateway 가 토큰 user_id 로 X-User-Id 를 만든다)
set -euo pipefail

KCADM=/opt/keycloak/bin/kcadm.sh
CONFIG=/tmp/kcadm-seed.config            # 파드의 홈 디렉터리는 쓰기 불가 — 임시 경로
REALM=gotgan
SERVER=${KC_SEED_SERVER:-http://localhost:8080}

if [ -z "${SEED_ADMIN_PASSWORD:-}" ] || [ -z "${SEED_DEMO_PASSWORD:-}" ]; then
  echo "SEED_ADMIN_PASSWORD · SEED_DEMO_PASSWORD 가 없어 시드 계정을 건너뜀" >&2
  exit 0
fi

kc() { "$KCADM" "$@" --config "$CONFIG"; }

"$KCADM" config credentials --config "$CONFIG" --server "$SERVER" --realm master \
  --user "$KC_BOOTSTRAP_ADMIN_USERNAME" --password "$KC_BOOTSTRAP_ADMIN_PASSWORD" >/dev/null

# seed_user 이메일 이름 비밀번호 user_id store_id(없으면 -) 추가역할...
seed_user() {
  local email=$1 name=$2 password=$3 user_id=$4 store_id=$5
  shift 5
  local attrs="\"user_id\":[\"$user_id\"]"
  [ "$store_id" != "-" ] && attrs="$attrs,\"store_id\":[\"$store_id\"]"

  local id
  id=$(kc get users -r "$REALM" -q email="$email" -q exact=true --fields id --format csv --noquotes)
  if [ -z "$id" ]; then
    id=$(echo "{\"email\":\"$email\",\"enabled\":true,\"emailVerified\":true,\"firstName\":\"$name\",\"attributes\":{$attrs}}" \
      | kc create users -r "$REALM" -f - -i)
    kc set-password -r "$REALM" --userid "$id" --new-password "$password"
    echo "  + $email 생성 (user_id=$user_id, store_id=$store_id)"
  else
    echo "{\"attributes\":{$attrs}}" | kc update "users/$id" -r "$REALM" -f - --merge
    echo "  = $email 이미 있음 — 속성 · 역할만 확인"
  fi
  for role in "$@"; do
    kc add-roles -r "$REALM" --uid "$id" --rolename "$role"
  done
}

echo "Keycloak 시드 계정 (realm $REALM)"
#         이메일                 이름          비밀번호               user_id store_id 추가 역할 (BUYER 는 기본 역할로 자동)
seed_user admin@gotgan.com       "곳간 관리자" "$SEED_ADMIN_PASSWORD" 1       -        ADMIN
seed_user seller1@gotgan.com     "판매자1"     "$SEED_DEMO_PASSWORD"  2       1        SELLER
seed_user seller2@gotgan.com     "판매자2"     "$SEED_DEMO_PASSWORD"  3       2        SELLER
seed_user buyer1@gotgan.com      "구매자1"     "$SEED_DEMO_PASSWORD"  4       -
seed_user buyer2@gotgan.com      "구매자2"     "$SEED_DEMO_PASSWORD"  5       -
seed_user buyer3@gotgan.com      "구매자3"     "$SEED_DEMO_PASSWORD"  6       -

rm -f "$CONFIG"
echo "완료"
