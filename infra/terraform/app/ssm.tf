# SSM 파라미터 /sesac-gojigi/dev/{종류}/{이름} — Lambda 가 읽을 큐 ARN · 테이블 이름 · 버킷 · SES 발신 주소 (serverless.yml 의 ${ssm:...})

# serverless.yml 이 ${ssm:...} 로 읽는 값 — 경로는 serverless/*/serverless.yml 과 정확히 같아야 한다
locals {
  ssm_parameters = {
    "s3/log-archive-bucket"             = aws_s3_bucket.this["log-archive"].bucket
    "s3/reports-bucket"                 = aws_s3_bucket.this["reports"].bucket
    "dynamodb/notifications-table"      = aws_dynamodb_table.notifications.name
    "dynamodb/settlement-reports-table" = aws_dynamodb_table.settlement_reports.name
    "ses/from-email"                    = var.ses_sender_email
    "sqs/notification-order-queue-arn"  = aws_sqs_queue.this["notification-order-events"].arn
    "sqs/notification-store-queue-arn"  = aws_sqs_queue.this["notification-store-events"].arn
    "sqs/report-settlement-queue-arn"   = aws_sqs_queue.this["report-settlement-events"].arn
  }
}

resource "aws_ssm_parameter" "this" {
  for_each = local.ssm_parameters

  name  = "/sesac-gojigi/dev/${each.key}"
  type  = "String" # 비밀 아님 — 이름 · ARN 만
  value = each.value
}
