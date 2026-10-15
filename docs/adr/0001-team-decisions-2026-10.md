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
