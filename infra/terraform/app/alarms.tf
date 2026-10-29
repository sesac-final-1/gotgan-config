# DLQ 감시 — 3회 처리 실패한 메시지가 DLQ 에 1건이라도 들어오면 알람 → SNS sesac-gojigi-alerts → 이메일 (장애 대비 점검 10/20, 담당 구지훈)
# 이전에는 DLQ 에 쌓여도 아무도 몰랐다. 재처리 절차: gotgan-backend docs/api/settlement.md 6절 (원인 수정 → start-message-move-task)
# 비용: 알람 1개 월 $0.10 × 구독 큐 수(9) + KMS 키 월 $1 — 이메일 구독은 apply 후 받은 확인 메일의 링크를 눌러야 발송된다

# 알림 토픽 암호화 키 — CloudWatch 알람은 AWS 관리형 키(aws/sns)로 암호화된 토픽에 발행할 수 없어서 고객 관리형 키에 cloudwatch 권한을 준다 (Sonar terraform:S6327)
resource "aws_kms_key" "alerts" {
  description         = "sesac-gojigi-alerts SNS 토픽 암호화 (CloudWatch 알람 발행 허용)"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CloudWatchAlarmsPublish"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = ["kms:Decrypt", "kms:GenerateDataKey*"]
        Resource  = "*"
      },
    ]
  })
}

resource "aws_kms_alias" "alerts" {
  name          = "alias/sesac-gojigi-alerts"
  target_key_id = aws_kms_key.alerts.key_id
}

resource "aws_sns_topic" "alerts" {
  name              = "sesac-gojigi-alerts"
  kms_master_key_id = aws_kms_key.alerts.arn
}

resource "aws_sns_topic_subscription" "alerts_email" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  for_each = local.subscriptions # sns_sqs.tf 의 구독 큐마다 DLQ 1개

  alarm_name          = "sesac-gojigi-${each.key}-dlq-not-empty"
  alarm_description   = "DLQ sesac-gojigi-${each.key}-dlq 에 메시지가 있음 — 소비자가 3회 처리 실패. 원인 확인 후 재처리(settlement.md 6절)"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.dlq[each.key].name }
  statistic           = "Maximum"
  period              = 300 # SQS 지표는 5분 단위로 올라온다
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching" # 빈 큐는 지표가 안 올 때가 있음 — 정상으로 본다
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn] # 재처리로 비면 해제 알림
}

# 일일 스케줄 감시 (10/29 코드리뷰 A-구-7) — Lambda infra-dispatch 가 GitHub workflow_dispatch 를 못 보내면(토큰 만료 · GitHub 장애 등)
# 08:00 apply · 22:00 destroy 가 아예 시작되지 않는다. destroy 가 빠지면 밤새 EKS · NAT 과금 — 워크플로 안의 실패는 infra-schedule.yml notify-failure 잡이 같은 토픽으로
resource "aws_cloudwatch_metric_alarm" "infra_dispatch_errors" {
  alarm_name          = "sesac-gojigi-infra-dispatch-errors"
  alarm_description   = "Lambda ${local.infra_dispatch.name} 실패 — 일일 apply · destroy 가 시작되지 않았을 수 있음. CloudWatch Logs 확인 후 Actions → infra-schedule 수동 실행"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.infra_dispatch.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  treat_missing_data  = "notBreaching" # 하루 두 번만 실행 — 나머지 시간은 지표 없음
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
