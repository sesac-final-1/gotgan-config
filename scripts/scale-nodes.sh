#!/bin/bash
# 노드 그룹 desired 0 ↔ 2 — **수동 보조 도구** (예: 낮에 잠깐 비용을 아끼고 싶을 때). 담당 구지훈 · 가이드라인 04장
# 표준은 infra-schedule.yml (07:00 cluster/ apply · 21:00 destroy) 이며 이 스크립트는 그 사이에만 쓴다. 야간 비용 절감 목적의 "노드 0" 운영은 폐기됨 (10/13 결정 3)
# 사용: ./scripts/scale-nodes.sh down | up   (AWS 자격 증명 필요 — 구지훈 로컬)
set -euo pipefail
CLUSTER="${EKS_CLUSTER_NAME:-sesac-gojigi-eks-cluster}"
NODEGROUP="${EKS_NODEGROUP_NAME:-sesac-gojigi-app}"   # cluster/ 노드 그룹 이름 고정 (output node_group_names). db 노드는 MySQL · Redis 라 건드리지 않는다
case "${1:-}" in
  down) DESIRED=0 ;;
  up)   DESIRED=2 ;;
  *) echo "usage: $0 down|up"; exit 1 ;;
esac
aws eks update-nodegroup-config --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" \
  --scaling-config minSize=0,maxSize=3,desiredSize="$DESIRED"
echo "nodegroup $NODEGROUP → desired=$DESIRED"
