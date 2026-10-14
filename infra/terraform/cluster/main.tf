# EKS 모듈(~> 20) — 1.35 · 퍼블릭 엔드포인트 · OIDC 공급자. apply 순서 6 (cicd · app 다음 — 둘의 output 을 읽는다)
# access_entries — 팀원 4명(IAM 사용자, variables.tf team_iam_users) + GitHub Actions 역할(cicd/ remote state) 모두 AmazonEKSClusterAdminPolicy(cluster 범위) 로 동일하게.
#   enable_cluster_creator_admin_permissions = false — 매일 08:00 클러스터를 만드는 주체가 Actions 역할이라 true 면 그 역할만 관리자가 된다. 생성자를 access_entries 에도 적으면 중복 오류
# 노드 그룹 2개 (3티어, 10/13 3차 · 10/14 사이징 조정):
#   app = t3.xlarge ×2 (4 vCPU · 16GiB · 파드 58/노드, AL2023, min 0 · max 3 · desired 2, 프라이빗 2a · 2c, gp3 40GiB 암호화, 라벨 tier=app)
#         — gateway ×2 · 업무 서비스 8 · Keycloak · 관측성 5 · ArgoCD 5 · 시스템 ≈ 35 파드 · requests 약 9.8Gi · 실사용 약 12~13Gi (할당 약 30Gi, 노드 1대로도 수용)
#         — 10/14 t3.large ×2 에서 조정: 실사용 여유 1~2Gi · 08:00 JVM 동시 기동 CPU 크레딧 · N-1 시연 불가. 약 $0.208/h × 2 → 6주 약 $245
#   db  = t3.medium ×1 (AL2023, min 0 · max 1 · desired 1, 프라이빗 2a 고정, gp3 20GiB 암호화, 라벨 tier=db + 테인트 tier=db:NoSchedule)
#         — MySQL · Redis 만 (toleration). EBS gp3 PVC 가 2a 에 묶이므로 서브넷은 private_subnets[0](2a) 하나. 약 $0.052/h → 6주 약 $31
#   Helm deployment.yaml 은 nodeSelector tier=app, deploy/k8s/db/*.yaml 은 nodeSelector tier=db + toleration
# VPC CNI 애드온에 enableNetworkPolicy=true (deploy/k8s/02-networkpolicy.yaml 이 DB 티어 3306 · 6379 를 tier=backend 파드만 허용)
# 애드온은 lbc.tf · ebs-csi-driver.tf · metrics-server.tf 뿐 (ESO 없음 — 시크릿은 secrets-sync 워크플로). IRSA 역할은 irsa.tf. 매일 08:00 apply · 22:00 destroy (infra-schedule.yml)
# 담당 구지훈 · 가이드라인 04장(main.tf 예시 코드) · 스펙 03-4
