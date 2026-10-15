# 다른 폴더 · 사람이 쓸 값 — terraform_remote_state 로 읽힌다. github_actions_role_arn → GitHub Secret AWS_ROLE_ARN(config · backend) · cluster/ access_entries

output "github_actions_role_arn" {
  description = "GitHub Actions OIDC 역할 ARN — GitHub Secret AWS_ROLE_ARN (gotgan-config · gotgan-backend) 에 등록"
  value       = aws_iam_role.github_actions.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC 공급자 ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}
