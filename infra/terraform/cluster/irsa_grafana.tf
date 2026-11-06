# sesac-gojigi-grafana-irsa — Grafana CloudWatch 데이터소스 읽기 전용 (담당 박지연)
# 대상: Lambda 로그(/aws/lambda/sesac-gojigi-*) · 지표(SQS DLQ 등). 쓰기 · 삭제 권한 없음
# 역할 이름 고정 → ARN 불변. 신뢰 정책은 그날의 OIDC 공급자 — 클러스터와 함께 매일 재생성 (irsa.tf 와 같음)

locals {
  grafana_lambda_log_group = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/sesac-gojigi-*"
}

resource "aws_iam_policy" "grafana" {
  name        = "sesac-gojigi-grafana-irsa-policy"
  description = "grafana CloudWatch 읽기 전용 (IRSA)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadLambdaLogs"
        Effect = "Allow"
        Action = ["logs:StartQuery", "logs:GetLogGroupFields", "logs:FilterLogEvents", "logs:DescribeLogStreams", "logs:GetLogEvents"]
        Resource = [
          local.grafana_lambda_log_group,
          "${local.grafana_lambda_log_group}:*",
        ]
      },
      {
        # 아래 API 는 리소스 단위 제한을 지원하지 않아 "*" (모두 읽기 전용)
        Sid      = "ReadWithoutResourceScope"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups", "logs:GetQueryResults", "logs:StopQuery", "cloudwatch:ListMetrics", "cloudwatch:GetMetricData", "cloudwatch:GetMetricStatistics"]
        Resource = "*"
      },
    ]
  })
}

module "grafana_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name        = "sesac-gojigi-grafana-irsa"
  role_policy_arns = { main = aws_iam_policy.grafana.arn }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["monitoring:grafana"] # grafana.yaml ServiceAccount
    }
  }
}
