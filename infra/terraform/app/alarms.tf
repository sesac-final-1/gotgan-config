# DLQ 감시 — 3회 처리 실패한 메시지가 DLQ 에 1건이라도 들어오면 알람 → SNS sesac-gojigi-alerts → 이메일 (장애 대비 점검 10/20, 담당 구지훈)
# 이전에는 DLQ 에 쌓여도 아무도 몰랐다. 재처리 절차: gotgan-backend docs/api/settlement.md 6절 (원인 수정 → start-message-move-task)
# 비용: 알람 1개 월 $0.10 × 구독 큐 수(9) — 이메일 구독은 apply 후 받은 확인 메일의 링크를 눌러야 발송된다

resource "aws_sns_topic" "alerts" {
  name = "sesac-gojigi-alerts"
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
