# 버킷 4개 — sesac-gojigi-images-{계정4}(prefix products/ · reviews/, presigned PUT CORS) · sesac-gojigi-seller-docs-{계정4} · sesac-gojigi-reports-{계정4} · sesac-gojigi-log-archive-{계정4}(90일 후 Glacier 수명주기)

locals {
  # 용도 → 이름. images 만 일부 공개(products/ · reviews/ 읽기), 나머지는 비공개
  buckets = {
    images      = "sesac-gojigi-images-${local.suffix}"      # 상품 · 리뷰 이미지 (presigned PUT, 공개 GET)
    seller-docs = "sesac-gojigi-seller-docs-${local.suffix}" # 입점 서류 (비공개)
    reports     = "sesac-gojigi-reports-${local.suffix}"     # 정산 명세서 CSV (비공개, 메일의 presigned 링크)
    log-archive = "sesac-gojigi-log-archive-${local.suffix}" # Lambda 로그 보관 (비공개, 90일 후 Glacier)
  }
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket        = each.value
  force_destroy = true # 발표 후 전체 destroy 때 객체가 남아 있어도 삭제
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# images 만 버킷 정책 공개를 허용(아래 images_public_read), ACL 공개는 전 버킷 차단
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this

  bucket                  = each.value.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = each.key != "images"
  restrict_public_buckets = each.key != "images"
}
