# 테이블 3개 — sesac-gojigi-notifications(PK USER#{userId} / SK {occurredAt}#{eventId}, TTL 90일) · sesac-gojigi-settlement-reports(PK STORE#{storeId} / SK WEEK#{주차}) ·
#   sesac-gojigi-inbox(알림 센터 — PK 받는 쪽 / SK {occurredAt}#{eventId}, TTL 90일). PAY_PER_REQUEST

# 알림 Lambda — 멱등(같은 eventId 재처리 방지) · 사용자별 발송 이력. PK USER#{userId} · SK {발송시각}#{eventId}, 90일 TTL
resource "aws_dynamodb_table" "notifications" {
  name         = "sesac-gojigi-notifications"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }

  ttl {
    attribute_name = "ttl" # epoch 초 — 쓰기 시점 + 90일
    enabled        = true
  }
}

# 정산 명세서 Lambda — 발송 이력 · 멱등. PK STORE#{storeId} · SK SETTLEMENT#{settlementId}
#   조건부 쓰기(attribute_not_exists(SK))로 같은 정산 재발송 방지, 스토어별 이력은 PK 로 조회
resource "aws_dynamodb_table" "settlement_reports" {
  name         = "sesac-gojigi-settlement-reports"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
}

# 알림 센터 알림함 (NTF-08, 10/27) — admin-service notification 이 쓰고 읽는다. 메일 발송 이력(notifications)과 읽음 상태가 섞이지 않게 따로
#   PK 받는 쪽: USER#{userId} · STORE#{storeId}(판매자 — 스토어 단위) · ADMIN(관리자 전원) / SK {occurredAt}#{eventId}(같은 이벤트 재전달은 같은 키 → 멱등)
resource "aws_dynamodb_table" "inbox" {
  name         = "sesac-gojigi-inbox"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }

  ttl {
    attribute_name = "ttl" # epoch 초 — 쓰기 시점 + 90일
    enabled        = true
  }
}
