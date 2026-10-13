# SNS 토픽 3개 — sesac-gojigi-store-events · sesac-gojigi-order-events · sesac-gojigi-settlement-events
# 구독자별 SQS 큐 + DLQ(-dlq, maxReceiveCount 3) + 필터 정책(필요한 eventType 만) · Raw message delivery 켬 (가이드라인 10장):
#   store-events      → sesac-gojigi-user-store-events · -product-store-events · -settlement-store-events · -notification-store-events
#   order-events      → sesac-gojigi-user-order-events · -review-order-events · -settlement-order-events · -notification-order-events
#   settlement-events → sesac-gojigi-report-settlement-events
