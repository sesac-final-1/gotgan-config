# 다른 폴더 · 사람이 쓸 값 — terraform_remote_state 로 읽힌다

output "tfstate_bucket_name" {
  description = "Terraform 상태 버킷 이름 — 각 폴더 provider.tf 의 backend \"s3\" bucket 값"
  value       = aws_s3_bucket.tfstate.bucket
}

output "tfstate_bucket_arn" {
  description = "Terraform 상태 버킷 ARN — cicd/ Actions 역할의 상태 읽기/쓰기 권한 대상"
  value       = aws_s3_bucket.tfstate.arn
}
