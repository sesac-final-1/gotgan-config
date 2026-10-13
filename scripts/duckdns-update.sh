#!/bin/bash
# DuckDNS 도메인 IP 갱신 — EIP 가 바뀐 경우만 (EIP 는 app/ 상시 자원이라 평소엔 안 바뀐다). 담당 구지훈 · 가이드라인 05장
# 사용: DOMAIN=gotgan-api EIP=1.2.3.4 DUCKDNS_TOKEN=... ./scripts/duckdns-update.sh   (bootstrap 워크플로가 같은 방식으로 호출)
# 토큰은 환경 변수 DUCKDNS_TOKEN (GitHub Secret) — 커밋 금지
set -euo pipefail
: "${DOMAIN:?DOMAIN 필요 (예: gotgan-api)}"
: "${EIP:?EIP 필요}"
: "${DUCKDNS_TOKEN:?DUCKDNS_TOKEN 필요}"
res=$(curl -fsS "https://www.duckdns.org/update?domains=${DOMAIN}&token=${DUCKDNS_TOKEN}&ip=${EIP}")
echo "duckdns ${DOMAIN} → ${EIP}: ${res}"
[ "$res" = "OK" ]
