# 클러스터 일일 스케줄 — EventBridge Scheduler(Asia/Seoul) → Lambda infra-dispatch → GitHub infra-schedule workflow_dispatch. 담당 구지훈
# GitHub 예약(schedule)은 정각 혼잡으로 1.5~4시간 늦게 시작돼(10/23~26 삭제 21:00 → 실제 00:10~01:22) 10/26 서버리스로 옮김 — 신호 → 잡 시작 3~5초.
# 08:00 apply(약 27분 → 08:30 사용) · 22:00 destroy. app/ 은 상시 폴더라 스케줄러는 클러스터가 없어도 남는다.
# GitHub 토큰: SSM SecureString(AWS 관리형 키 aws/ssm) — "시크릿은 GitHub Secrets 단일 소스" 규칙의 예외 1건(10/26 팀 결정, docs/secrets.md).
#   값은 Terraform 이 만들지 않는다(상태 파일에 남지 않게) → 구지훈이 CLI 로 직접 등록 (docs/secrets.md 7절)

locals {
  infra_dispatch = {
    name            = "sesac-gojigi-infra-dispatch"
    token_parameter = "/sesac-gojigi/dev/github/infra-dispatch-token"
    schedules = {
      apply   = "cron(0 8 * * ? *)"  # 매일 08:00 KST
      destroy = "cron(0 22 * * ? *)" # 매일 22:00 KST
    }
  }
}

data "archive_file" "infra_dispatch" {
  type        = "zip"
  source_file = "${path.module}/lambda/infra-dispatch/index.mjs"
  output_path = "${path.module}/.build/infra-dispatch.zip"
}

# ── Lambda 실행 역할 — 로그 · 토큰 파라미터 읽기만
data "aws_iam_policy_document" "infra_dispatch_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "infra_dispatch" {
  name               = local.infra_dispatch.name
  assume_role_policy = data.aws_iam_policy_document.infra_dispatch_trust.json
}

resource "aws_iam_role_policy_attachment" "infra_dispatch_logs" {
  role       = aws_iam_role.infra_dispatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# AWS 관리형 키(aws/ssm)는 SSM 을 거친 복호화를 계정 주체에게 허용 → kms 권한 없이 GetParameter(WithDecryption)만
resource "aws_iam_role_policy" "infra_dispatch_token" {
  name = "read-token"
  role = aws_iam_role.infra_dispatch.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:GetParameter"
      Resource = "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter${local.infra_dispatch.token_parameter}"
    }]
  })
}

resource "aws_cloudwatch_log_group" "infra_dispatch" {
  name              = "/aws/lambda/${local.infra_dispatch.name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "infra_dispatch" {
  function_name    = local.infra_dispatch.name
  description      = "08:00 apply · 22:00 destroy — GitHub infra-schedule workflow_dispatch"
  role             = aws_iam_role.infra_dispatch.arn
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  filename         = data.archive_file.infra_dispatch.output_path
  source_code_hash = data.archive_file.infra_dispatch.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      TOKEN_PARAMETER = local.infra_dispatch.token_parameter
      GITHUB_REPO     = var.infra_schedule_repo
      WORKFLOW_FILE   = "infra-schedule.yml"
    }
  }

  depends_on = [aws_cloudwatch_log_group.infra_dispatch, aws_iam_role_policy_attachment.infra_dispatch_logs]
}

# ── 스케줄러 → Lambda 호출 역할
data "aws_iam_policy_document" "infra_scheduler_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "infra_scheduler" {
  name               = "sesac-gojigi-infra-scheduler"
  assume_role_policy = data.aws_iam_policy_document.infra_scheduler_trust.json
}

resource "aws_iam_role_policy" "infra_scheduler_invoke" {
  name = "invoke-infra-dispatch"
  role = aws_iam_role.infra_scheduler.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "lambda:InvokeFunction", Resource = aws_lambda_function.infra_dispatch.arn }]
  })
}

resource "aws_scheduler_schedule" "infra" {
  for_each = local.infra_dispatch.schedules

  name                         = "sesac-gojigi-infra-${each.key}"
  schedule_expression          = each.value
  schedule_expression_timezone = "Asia/Seoul"

  flexible_time_window {
    mode = "OFF" # 정각에 바로
  }

  target {
    arn      = aws_lambda_function.infra_dispatch.arn
    role_arn = aws_iam_role.infra_scheduler.arn
    input    = jsonencode({ action = each.key })

    retry_policy {
      maximum_event_age_in_seconds = 3600 # 1시간 안에 못 부르면 버림 — 늦은 apply · destroy 가 다음 일정과 엉키지 않게
      maximum_retry_attempts       = 2
    }
  }
}
