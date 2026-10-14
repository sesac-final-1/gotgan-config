# GitHub OIDC 공급자 · Actions 역할(ECR push · Serverless 배포 · SSM 읽기) — 이경석 작성 · 구지훈 리뷰. apply 순서 4 (cluster 보다 먼저 — cluster 의 access_entries 가 Actions 역할 ARN 을 읽는다). output → GitHub Secret AWS_ROLE_ARN
# 신뢰 정책 조건 token.actions.githubusercontent.com:sub — 하나라도 빠지면 그 워크플로가 AssumeRole 에서 실패
#   repo:sesac-final-1/gotgan-config:ref:refs/heads/main   (infra-schedule 스케줄 · bootstrap · secrets-sync · workflow_dispatch)
#   repo:sesac-final-1/gotgan-config:pull_request          (infra.yml PR plan)
#   repo:sesac-final-1/gotgan-backend:*                    (backend.yml ECR push · serverless.yml)
# 권한: infra-schedule 이 cluster/ 를 apply · destroy 한다 → EKS · EC2 · IAM(IRSA 역할 생성) · tfstate 버킷 읽기/쓰기까지 필요
# 담당 구지훈 · 가이드라인 04장 · 스펙 03-4
