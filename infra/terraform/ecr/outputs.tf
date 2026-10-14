# 다른 폴더 · 사람이 쓸 값 — terraform_remote_state 로 읽힌다

output "repository_urls" {
  description = "서비스별 저장소 URL (map: 서비스 → {계정}.dkr.ecr.{리전}.amazonaws.com/sesac-gojigi-{서비스}) — Helm values image · backend.yml 참고"
  value       = { for k, r in aws_ecr_repository.service : k => r.repository_url }
}

output "repository_arns" {
  description = "서비스별 저장소 ARN — cicd/ Actions 역할의 ECR push 권한 대상"
  value       = [for r in aws_ecr_repository.service : r.arn]
}

output "registry_id" {
  description = "ECR 레지스트리(계정) ID — 이미지 주소 앞부분"
  value       = one(distinct([for r in aws_ecr_repository.service : r.registry_id]))
}
