# terraform_remote_state — vpc(vpc_id · private_subnets) · app(S3 · SQS · SNS ARN → irsa.tf)
# 의존 방향은 cluster → 상시 폴더 한쪽뿐. 상시 폴더(app 등)는 cluster 를 읽지 않는다 — cluster 는 매일 22:00 사라진다
# data "aws_iam_roles" github_actions — name_regex "^sesac-gojigi-github-actions$" (cicd/, 이경석). 없으면 빈 목록이라 에러 없이 access_entries 에서 빠진다
#   → cicd/ apply 전에도 cluster apply 가능, 역할이 생기면 다음 apply(매일 08:00) 때 자동 포함
