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
| `StoreApproved` | store-events | store | user(SELLER 역할 · store_id) · settlement(스토어명 · 정산 계좌 스냅샷) · 알림 Lambda(승인 메일) · admin 알림 센터(`STORE_APPROVED` 화면 알림, 10/27) | storeId · userId · storeName · sellerEmail · settlementAccount{bank, number, holder} |
| `StoreApplicationRejected` | store-events | store | 알림 Lambda(입점 반려 메일) — 10/15 추가 · admin 알림 센터(`STORE_REJECTED`, 10/27) | applicationId · userId · storeName · sellerEmail · reason (재신청 제한 30일 안내용 decidedAt) — userId 10/21 추가(알림 이력 키) |
| `StoreApplicationSupplementRequested` | store-events | store | 알림 Lambda(보완요청 메일 — 7일 내 미보완 시 자동 반려 안내) — 10/15 추가 · admin 알림 센터(`STORE_SUPPLEMENT`, 10/27) | applicationId · userId · storeName · sellerEmail · requestedDocs[] · message · dueAt — userId 10/21 추가(알림 이력 키) |
| `StoreStatusChanged` | store-events | store | product(상품 노출 숨김) · settlement(지급 보류) | storeId · status |
| `OrderPaid` | order-events | order | 알림 Lambda(주문 확인 메일 — earnedPoint 는 적립 예정액) · admin 알림 센터(`ORDER_PAID`, 10/27) | orderNo · buyerId · ordererEmail · ordererName · payAmt · usedPoint · items[{orderItemId, earnedPoint, productName, optionName, quantity, itemAmt}] — ordererName 부터는 10/21 추가(주문 확인 메일 본문, 알림 Lambda 는 order 를 동기 호출하지 않음). 뒤 필드는 추가분. 10/27 포인트 적립은 구매확정(`OrderItemConfirmed`)으로 옮김 — user 는 이 이벤트를 적립에 쓰지 않음 |
| `OrderItemShipped` | order-events | order | 알림 Lambda(배송 시작 메일) · admin 알림 센터(`ORDER_SHIPPED`, 10/27) | orderItemId · orderNo · buyerId · ordererEmail · ordererName · productName · optionName · courier · trackingNo — buyerId · ordererName · productName · optionName 은 10/21 추가(배송 시작 메일) |
| `OrderItemConfirmed` | order-events | order | settlement(정산 적재) · review(리뷰 작성 자격) · user(5% 포인트 적립 · 누적 구매액 → 등급) | orderItemId · orderNo · buyerId · storeId · productId · productName · categoryId(하위) · topCategoryId(상위 — 판매수수료 기준) · itemAmt · earnedPoint · confirmedAt · buyerDisplayName · optionName · thumbnailUrl — productName · topCategoryId 는 10/16 추가(settlement 정산 상세 · 수수료율, settlement 는 product 를 동기 호출하지 않음). earnedPoint(상품주문 적립 포인트, 주문 시점 계산)는 10/27 추가 — user 가 이 값대로 적립, settlement 는 쓰지 않음(모르는 필드 무시). buyerDisplayName(orders.orderer_display_name — 닉네임, 없으면 마스킹 실명) · optionName · thumbnailUrl(order_item 주문 시점 스냅샷, 옵션 없는 상품 · 썸네일 없으면 null)은 10/28 추가 — review 작성 자격 스냅샷(공개 리뷰 작성자 이름 · 마이페이지 리뷰 화면, review 는 order · user · product 를 호출하지 않음), settlement · user 는 쓰지 않음 |
| `OrderItemCancelled` · `OrderItemReturned` | order-events | order | 알림 Lambda(취소/반품 완료 메일) · admin 알림 센터(`ORDER_CANCELLED` · `ORDER_RETURNED`, 10/27) | orderItemId · orderNo · buyerId · ordererEmail · ordererName · productName · optionName · refundAmt · restoredPoint · revokedPoint — buyerId · ordererName · productName · optionName · restoredPoint · revokedPoint 는 10/21 추가(취소/반품 완료 메일) |

order 이벤트 필드 (10/21 추가분, 값은 모두 주문 시점 스냅샷)

- `ordererName`: 주문자 실명(`orders.orderer_name`) — 메일 본문용, 화면 공개 금지
- `optionName`: 옵션 없는 상품이면 `null`
- `usedPoint`(OrderPaid): 주문 전체 사용 포인트(`orders.used_point`) · `itemAmt`: 상품주문 금액(`order_item.item_amt`)
- `restoredPoint`: 돌려준 사용 포인트(`order_item.used_point`) · `revokedPoint`: 회수한 적립 포인트 — 10/27부터 항상 0 (적립이 구매확정 때이고 취소 · 반품은 구매확정 전에만 되므로 회수할 적립이 없다)
| `SettlementPaid` | settlement-events | settlement | 정산 명세서 Lambda · admin 알림 센터(스토어에 `SETTLEMENT_PAID`, 10/27) | settlementId · storeId · week · payoutAmt · sellerEmail · storeName · weekStart · weekEnd · paidAt · salesAmt · commissionAmt · paymentFeeAmt · items[{orderNo · productName · confirmedAt · itemAmt · commissionRate · commissionAmt · paymentFeeAmt · payoutAmt}] — 명세서 내용을 모두 담음(10/21 방식 B, backend #57). 뒤 필드는 추가분 |

## 순서 규칙 (10/15 결정 — A안)

SNS + SQS 표준 큐는 **도착 순서를 보장하지 않는다** (재시도된 메시지가 나중 메시지보다 늦게 처리될 수 있음).

- **상태를 덮어쓰는 이벤트는 소비자가 `occurredAt` 을 비교해 옛 이벤트를 무시한다**
  - 반영 대상 행에 "마지막으로 반영한 occurredAt" 컬럼을 두고, 비교 · 갱신을 UPDATE 한 문장으로:
    `UPDATE … SET status = :status, {x}_changed_at = :occurredAt WHERE id = :id AND ({x}_changed_at IS NULL OR {x}_changed_at < :occurredAt)`
  - 0행 갱신 = 옛 이벤트 → 무시(로그만), `processed_event` 에는 기록
  - occurredAt 은 Asia/Seoul `LocalDateTime` 으로 변환해 DB `DATETIME(6)` 과 비교
- **적용 대상**: `StoreStatusChanged` → product(`product.store_status_changed_at`, 박지연) · settlement(`settlement_store.store_status_changed_at`, 구지훈)
- **적용하지 않는 이벤트**: 누적 · 한 번만 일어나는 이벤트(`OrderItemConfirmed` 포인트 적립 · 정산 적재, `StoreApproved` 등)는 `processed_event` 중복 방지로 충분
- 새로 "상태를 덮어쓰는" 이벤트를 추가하면 이 규칙을 같이 적용하고 위 대상 목록에 추가한다
- 기준이 되는 행이 아직 없으면(예: `StoreApproved` 보다 `StoreStatusChanged` 가 먼저 도착) `processed_event` 를 남기지 않고 예외로 메시지를 큐에 돌려 재시도 (3회 실패 시 DLQ)
- 대안 검토: FIFO(B안)는 토픽 · 큐 · 구독 전체 재생성 + 모든 구독자 영향이라 채택 안 함, 그대로 둠(C안)은 지급 보류 · 상품 노출이 틀어질 수 있어 채택 안 함

## 큐 (구독자별, 컨벤션 5-1)

- store-events → `sesac-gojigi-user-store-events` · `-product-store-events` · `-settlement-store-events` · `-notification-store-events`
- order-events → `sesac-gojigi-user-order-events` · `-review-order-events` · `-settlement-order-events` · `-notification-order-events`
- settlement-events → `sesac-gojigi-report-settlement-events`
- 알림 센터(admin-service, NTF-08 — 10/27) → `sesac-gojigi-admin-store-events` · `-admin-order-events` · `-admin-settlement-events` (메일 Lambda 와 같은 이벤트를 따로 받아 화면 알림함 · 실시간 SSE)
- 모든 큐에 DLQ(`-dlq`, 최대 수신 3회)
- 구독 필터: SNS 구독마다 **본문의 `eventType`** 으로 거른다(`filter_policy_scope = MessageBody`) — 발행 측은 MessageAttributes 를 달 필요 없이 봉투 JSON 만 publish. raw delivery 라 소비자는 봉투를 그대로 받는다
- 큐 URL · 토픽 ARN 은 ConfigMap `app-config`(`{소비자}_{도메인}_EVENTS_QUEUE_URL` · `{도메인}_EVENTS_TOPIC_ARN`), Lambda 는 SSM `/sesac-gojigi/dev/sqs/...`
- 구독 · 필터 정의: `infra/terraform/app/sns_sqs.tf` 의 `locals.subscriptions` — 이 표의 구독자를 바꾸면 그 파일도 함께 고친다
