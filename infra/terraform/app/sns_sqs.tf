# SNS 토픽 3개 — sesac-gojigi-store-events · sesac-gojigi-order-events · sesac-gojigi-settlement-events
# 구독자별 SQS 큐 + DLQ(-dlq, maxReceiveCount 3) + 필터 정책(필요한 eventType 만) · Raw message delivery 켬 (가이드라인 10장):
#   store-events      → sesac-gojigi-user-store-events · -product-store-events · -settlement-store-events · -notification-store-events
#   order-events      → sesac-gojigi-user-order-events · -review-order-events · -settlement-order-events · -notification-order-events
#   settlement-events → sesac-gojigi-report-settlement-events
#   알림 센터(admin-service, 10/27 NTF-08) → sesac-gojigi-admin-store-events · -admin-order-events · -admin-settlement-events

# 이벤트 계약: docs/events.md — 토픽 · 구독자 · 이벤트 타입이 바뀌면 여기와 함께 고친다
locals {
  topics = toset(["store", "order", "settlement"]) # sesac-gojigi-{도메인}-events

  # 구독 큐 sesac-gojigi-{소비자}-{도메인}-events → 받을 이벤트 (SNS 필터 정책, 봉투의 eventType)
  subscriptions = {
    "user-store-events"         = { topic = "store", events = ["StoreApproved"] }
    "product-store-events"      = { topic = "store", events = ["StoreStatusChanged"] }
    "settlement-store-events"   = { topic = "store", events = ["StoreApproved", "StoreStatusChanged"] }
    "notification-store-events" = { topic = "store", events = ["StoreApproved", "StoreApplicationRejected", "StoreApplicationSupplementRequested"] } # 입점 승인 · 반려 · 보완요청 메일
    "user-order-events"         = { topic = "order", events = ["OrderItemConfirmed"] }
    "review-order-events"       = { topic = "order", events = ["OrderItemConfirmed"] }
    "settlement-order-events"   = { topic = "order", events = ["OrderItemConfirmed"] }
    "notification-order-events" = { topic = "order", events = ["OrderPaid", "OrderItemShipped", "OrderItemCancelled", "OrderItemReturned"] }
    "report-settlement-events"  = { topic = "settlement", events = ["SettlementPaid"] }
    # 알림 센터(NTF-08) — 화면 알림함 · 실시간(SSE). 메일 Lambda 와 같은 이벤트를 따로 받는다
    "admin-store-events"      = { topic = "store", events = ["StoreApproved", "StoreApplicationRejected", "StoreApplicationSupplementRequested"] }
    "admin-order-events"      = { topic = "order", events = ["OrderPaid", "OrderItemShipped", "OrderItemCancelled", "OrderItemReturned"] }
    "admin-settlement-events" = { topic = "settlement", events = ["SettlementPaid"] }
  }
}

resource "aws_sns_topic" "events" {
  for_each = local.topics

  name = "sesac-gojigi-${each.key}-events"
}

# 3회 처리 실패한 메시지 보관 — 원인 확인 후 재처리(콘솔 redrive)
resource "aws_sqs_queue" "dlq" {
  for_each = local.subscriptions

  name                      = "sesac-gojigi-${each.key}-dlq"
  message_retention_seconds = 1209600 # 14일 (최대)
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "this" {
  for_each = local.subscriptions

  name                       = "sesac-gojigi-${each.key}"
  visibility_timeout_seconds = 60     # Lambda timeout(30s) 의 2배 · Spring 리스너 처리 여유
  receive_wait_time_seconds  = 20     # 롱 폴링 — 빈 응답 요청 수(비용) 감소
  message_retention_seconds  = 345600 # 4일
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = 3
  })
}

# 자기 토픽만 이 큐에 넣을 수 있게
resource "aws_sqs_queue_policy" "from_sns" {
  for_each = local.subscriptions

  queue_url = aws_sqs_queue.this[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSnsTopic"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.this[each.key].arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.events[each.value.topic].arn } }
    }]
  })
}

resource "aws_sns_topic_subscription" "this" {
  for_each = local.subscriptions

  topic_arn = aws_sns_topic.events[each.value.topic].arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.this[each.key].arn

  # 소비자가 SNS 래퍼 없이 봉투 JSON(eventId · eventType · payload …) 을 그대로 받는다
  raw_message_delivery = true

  # 메시지 속성이 아니라 본문의 eventType 으로 거른다 — 발행 측이 속성을 따로 달 필요 없음
  filter_policy_scope = "MessageBody"
  filter_policy       = jsonencode({ eventType = each.value.events })

  depends_on = [aws_sqs_queue_policy.from_sns]
}
