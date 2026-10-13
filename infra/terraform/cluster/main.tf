# EKS 모듈(~> 20) — 1.35 · 퍼블릭 엔드포인트 · 노드 그룹 t3.large (AL2023, min 0 · max 3 · desired 2, gp3 40GiB 암호화) · access_entries(팀원 4명 + GitHub Actions 역할) · OIDC 공급자. apply 순서 4
# 애드온은 lbc.tf · ebs-csi-driver.tf · metrics-server.tf 뿐 (ESO 없음 — 시크릿은 secrets-sync 워크플로). 매일 08:00 apply · 22:00 destroy (infra-schedule.yml)
# 담당 구지훈 · 가이드라인 04장 · 스펙 03-4
