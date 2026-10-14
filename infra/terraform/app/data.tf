# 현재는 data.aws_caller_identity(버킷 이름 계정 4자리)만. vpc remote state 는 작업용 EC2(선택)를 만들 때 추가. cluster 는 읽지 않는다 (상시 폴더가 매일 사라지는 cluster 에 의존하면 안 됨 — 순환 의존 방지)

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  suffix     = substr(local.account_id, length(local.account_id) - 4, 4) # S3 전역 유일 — 계정 ID 끝 4자리 (컨벤션 5-1)
}
