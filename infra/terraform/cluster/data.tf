# terraform_remote_state — vpc(vpc_id · private_subnets) · cicd(github_actions_role_arn → access_entries) · app(S3 · SQS · SNS ARN → irsa.tf)
# 의존 방향은 cluster → 상시 폴더 한쪽뿐. 상시 폴더(app 등)는 cluster 를 읽지 않는다 — cluster 는 매일 22:00 사라진다
