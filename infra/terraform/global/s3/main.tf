# 상태 파일 버킷(버전 관리 · 삭제 방지) — 잠금은 각 폴더 backend 의 use_lockfile(S3 자체 잠금)이라 DynamoDB 잠금 테이블은 만들지 않는다. 이 폴더만 상태가 로컬. apply 순서 1 (팀에서 1번)
# 담당 구지훈 · 가이드라인 04장 · 스펙 03-4

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  # 버킷 이름은 전역 유일 — 계정 ID 끝 4자리 (컨벤션 5-1 S3 규칙)
  bucket_name = "sesac-gojigi-tfstate-${substr(local.account_id, length(local.account_id) - 4, 4)}"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  # 모든 폴더의 상태가 여기 있다 — 실수로 destroy 하지 못하게
  lifecycle {
    prevent_destroy = true
  }
}

# 상태 파일을 잘못 덮어써도 이전 버전으로 되돌릴 수 있게
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
