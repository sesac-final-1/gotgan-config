# ADR-0001: 2026-10 팀 결정 요약 (컨벤션 회의 10/08 · 1차 멘토링 10/12)

- 날짜: 2026-10-12
- 상태: 확정
- 결정자: 구지훈 · 이경석 · 박지연 (멘토 피드백 반영 · 10/15 3인 체제로 담당 재배치 — order · review 이경석, payment 구지훈)

## 결정

- 서비스 9개 (gateway · user · store · product · order · payment · review · settlement · admin) + Keycloak. admin 은 DB 없는 조합 계층
- 카테고리 = product, 수수료 = settlement. 대시보드 = 서비스 안 조합 모듈 + 부분 응답
- 인증 = Gateway + Keycloak (user-service 대리 호출, Keycloak 내부 전용). Cognito 제외
- 모든 동기 호출 Resilience4j 표준 · 검색 QueryDSL · XSS Sanitizer · SonarQube Cloud
- 서버리스는 배치 · 로깅만 (알림 메일 · 정산 명세서 · 로그 아카이브)
- 제외: 오토스케일링 · 파티셔닝 · CQRS/캐시 · Elasticsearch · 썸네일 · 찜 · 쿠폰 · 비회원 구매 · 회원 신고

전체 근거와 상세는 가이드라인 18장 "결정 기록" (https://gotganguide.vercel.app/guideline#s15).

## 변경 (10/26)

- **회원 신고 범위 복귀** — 리뷰 신고와 같은 흐름(신고 접수 → 관리자 처리 → 리뷰 블라인드 · 회원 정지 · 기각)
- **admin DB 예외** — 신고 · 조치 이력만 `admindb`(report · moderation_action)에 둔다. 다른 서비스 데이터는 여전히 갖지 않고, 조치는 각 서비스 내부 API(review 블라인드 · user 정지)로 요청한다 (B안)
  - 이유: 신고는 리뷰 · 회원에 걸친 운영 기능이라 접수 · 처리 이력을 한 곳에 두고, 각 서비스는 "블라인드 / 정지" 상태만 갖게 해 담당 서비스의 변경을 최소로 한다
  - 인프라: `init-schemas.sh` admin 스키마 · 계정, `ADMIN_DB_PASSWORD` → `mysql-secret` · `admin-service-secret` (docs/secrets.md)
- 근거: 노션 확인 요청 「신고 · 리뷰 블라인드 (B안) · 리뷰 첫 설계에 블라인드 반영 부탁」(10/26)
