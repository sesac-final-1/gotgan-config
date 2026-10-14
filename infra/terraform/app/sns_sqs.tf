# SNS 토픽 3개 — sesac-gojigi-store-events · sesac-gojigi-order-events · sesac-gojigi-settlement-events
# 구독자별 SQS 큐 + DLQ(-dlq, maxReceiveCount 3) + 필터 정책(필요한 eventType 만) · Raw message delivery 켬 (가이드라인 10장):
#   store-events      → sesac-gojigi-user-store-events · -product-store-events · -settlement-store-events · -notification-store-events
#   order-events      → sesac-gojigi-user-order-events · -review-order-events · -settlement-order-events · -notification-order-events
#   settlement-events → sesac-gojigi-report-settlement-events

# 이벤트 계약: docs/events.md — 토픽 · 구독자 · 이벤트 타입이 바뀌면 여기와 함께 고친다
locals {
  topics = toset(["store", "order", "settlement"]) # sesac-gojigi-{도메인}-events

  # 구독 큐 sesac-gojigi-{소비자}-{도메인}-events → 받을 이벤트 (SNS 필터 정책, 봉투의 eventType)
  subscriptions = {
    "user-store-events"         = { topic = "store", events = ["StoreApproved"] }
    "product-store-events"      = { topic = "store", events = ["StoreStatusChanged"] }
    "settlement-store-events"   = { topic = "store", events = ["StoreApproved", "StoreStatusChanged"] }
    "notification-store-events" = { topic = "store", events = ["StoreApproved"] }
    "user-order-events"         = { topic = "order", events = ["OrderPaid", "OrderItemConfirmed"] }
    "review-order-events"       = { topic = "order", events = ["OrderItemConfirmed"] }
    "settlement-order-events"   = { topic = "order", events = ["OrderItemConfirmed"] }
    "notification-order-events" = { topic = "order", events = ["OrderPaid", "OrderItemShipped", "OrderItemCancelled", "OrderItemReturned"] }
    "report-settlement-events"  = { topic = "settlement", events = ["SettlementPaid"] }
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
