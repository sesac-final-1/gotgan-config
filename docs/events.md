# 이벤트 목록 (가이드라인 10장 · 컨벤션 2-7)

이벤트는 **구현 전에 여기에 먼저 등록**한다. 필드 추가는 자유, 삭제 · 이름 변경 · 의미 변경 금지 (새 이벤트 타입 또는 version 증가).

## 봉투 (전 팀 같은 형식)

```json
{
  "eventId": "6c1f0a6e-0b0e-4c5b-9a8b-2f3c8e7d1a10",
  "eventType": "OrderItemConfirmed",
  "occurredAt": "2026-10-21T09:12:33+09:00",
  "aggregateId": "20261014-000123-01",
  "version": 1,
  "payload": { }
}
```

- `eventId`: UUID — 소비자 멱등 처리 키 (`processed_event` 테이블)
- `occurredAt`: 오프셋 포함 ISO-8601 (Asia/Seoul)
- payload 는 구독자가 다시 호출하지 않아도 되도록 필요한 값을 담는다 (주문자 이메일 · 금액 등)

## 토픽 · 이벤트

| 이벤트 | 토픽 | 발행 | 구독 · 하는 일 | payload (담당자가 확정) |
|---|---|---|---|---|
| `StoreApproved` | store-events | store | user(SELLER 역할 · store_id) · settlement(스토어명 · 정산 계좌 스냅샷) · 알림 Lambda(승인 메일) | storeId · userId · storeName · sellerEmail · settlementAccount{bank, number, holder} |
| `StoreApplicationRejected` | store-events | store | 알림 Lambda(입점 반려 메일) — 10/15 추가 | applicationId · storeName · sellerEmail · reason (재신청 제한 30일 안내용 decidedAt) |
| `StoreApplicationSupplementRequested` | store-events | store | 알림 Lambda(보완요청 메일 — 7일 내 미보완 시 자동 반려 안내) — 10/15 추가 | applicationId · storeName · sellerEmail · requestedDocs[] · message · dueAt |
| `StoreStatusChanged` | store-events | store | product(상품 노출 숨김) · settlement(지급 보류) | storeId · status |
| `OrderPaid` | order-events | order | user(5% 포인트 적립) · 알림 Lambda(주문 확인 메일) | orderNo · buyerId · ordererEmail · payAmt · items[{orderItemId, earnedPoint}] |
| `OrderItemShipped` | order-events | order | 알림 Lambda(배송 시작 메일) | orderItemId · orderNo · ordererEmail · courier · trackingNo |
| `OrderItemConfirmed` | order-events | order | settlement(정산 적재) · review(리뷰 작성 자격) · user(누적 구매액 → 등급) | orderItemId · orderNo · buyerId · storeId · productId · productName · categoryId(하위) · topCategoryId(상위 — 판매수수료 기준) · itemAmt · confirmedAt — productName · topCategoryId 는 10/16 추가(settlement 정산 상세 · 수수료율, settlement 는 product 를 동기 호출하지 않음) |
| `OrderItemCancelled` · `OrderItemReturned` | order-events | order | 알림 Lambda(취소/반품 완료 메일) | orderItemId · orderNo · ordererEmail · refundAmt |
| `SettlementPaid` | settlement-events | settlement | 정산 명세서 Lambda | settlementId · storeId · week · payoutAmt · sellerEmail |

## 순서 규칙 (10/15 결정 — A안)

SNS + SQS 표준 큐는 **도착 순서를 보장하지 않는다** (재시도된 메시지가 나중 메시지보다 늦게 처리될 수 있음).

- **상태를 덮어쓰는 이벤트는 소비자가 `occurredAt` 을 비교해 옛 이벤트를 무시한다**
  - 반영 대상 행에 "마지막으로 반영한 occurredAt" 컬럼을 두고, 비교 · 갱신을 UPDATE 한 문장으로:
    `UPDATE … SET status = :status, {x}_changed_at = :occurredAt WHERE id = :id AND ({x}_changed_at IS NULL OR {x}_changed_at < :occurredAt)`
  - 0행 갱신 = 옛 이벤트 → 무시(로그만), `processed_event` 에는 기록
  - occurredAt 은 Asia/Seoul `LocalDateTime` 으로 변환해 DB `DATETIME(6)` 과 비교
- **적용 대상**: `StoreStatusChanged` → product(`product.store_status_changed_at`, 박지연) · settlement(`settlement_store.store_status_changed_at`, 구지훈)
- **적용하지 않는 이벤트**: 누적 · 한 번만 일어나는 이벤트(`OrderPaid` 포인트 적립, `OrderItemConfirmed` 정산 적재, `StoreApproved` 등)는 `processed_event` 중복 방지로 충분
- 새로 "상태를 덮어쓰는" 이벤트를 추가하면 이 규칙을 같이 적용하고 위 대상 목록에 추가한다
- 기준이 되는 행이 아직 없으면(예: `StoreApproved` 보다 `StoreStatusChanged` 가 먼저 도착) `processed_event` 를 남기지 않고 예외로 메시지를 큐에 돌려 재시도 (3회 실패 시 DLQ)
- 대안 검토: FIFO(B안)는 토픽 · 큐 · 구독 전체 재생성 + 모든 구독자 영향이라 채택 안 함, 그대로 둠(C안)은 지급 보류 · 상품 노출이 틀어질 수 있어 채택 안 함

## 큐 (구독자별, 컨벤션 5-1)

- store-events → `sesac-gojigi-user-store-events` · `-product-store-events` · `-settlement-store-events` · `-notification-store-events`
- order-events → `sesac-gojigi-user-order-events` · `-review-order-events` · `-settlement-order-events` · `-notification-order-events`
- settlement-events → `sesac-gojigi-report-settlement-events`
- 모든 큐에 DLQ(`-dlq`, 최대 수신 3회)
- 구독 필터: SNS 구독마다 **본문의 `eventType`** 으로 거른다(`filter_policy_scope = MessageBody`) — 발행 측은 MessageAttributes 를 달 필요 없이 봉투 JSON 만 publish. raw delivery 라 소비자는 봉투를 그대로 받는다
- 큐 URL · 토픽 ARN 은 ConfigMap `app-config`(`{소비자}_{도메인}_EVENTS_QUEUE_URL` · `{도메인}_EVENTS_TOPIC_ARN`), Lambda 는 SSM `/sesac-gojigi/dev/sqs/...`
- 구독 · 필터 정의: `infra/terraform/app/sns_sqs.tf` 의 `locals.subscriptions` — 이 표의 구독자를 바꾸면 그 파일도 함께 고친다
