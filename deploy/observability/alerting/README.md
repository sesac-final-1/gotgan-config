# 알림 규칙 (담당 박지연)

Grafana Alerting → Discord `alerts` 채널 + 관리자 벨. 웹훅 URL 은 GitHub Secret `ALERT_WEBHOOK_URL` 에만(커밋 금지).

| 파일 | 내용 |
| --- | --- |
| `rules.yaml` | 규칙 9개 — 서킷 OPEN · DB 커넥션 풀 대기 · 파드 재시작 · 메모리 limit 90% · 서비스 다운 · 5xx 비율 · Saga 실패 · 결제 금액 불일치 · 결제 취소 미해결 |
| `rules-logs.yaml` | 로그 기반 규칙 3개(Loki) — 이벤트 발행 한도 초과 · 요청 제한 오류 · Gateway 502/504 증가 |
| `contact-points.yaml` | Discord 웹훅 · 관리자 벨 `POST /internal/notifications` |
| `policies.yaml` | 규칙별로 묶어 30초 뒤 전송, 계속되면 4시간마다 다시 |

- 적용: bootstrap 이 이 폴더로 `grafana-alerting` ConfigMap 을 만든다 → 다음 08:00 생성 때 반영. 화면에서 고친 내용은 재시작 때 사라진다
- Saga **보상**은 넣지 않음 — 결제 대기 만료에서도 정상으로 생긴다. DLQ · 업로드 검사 · 인프라 스케줄 실패는 `sesac-gojigi-alerts` 메일
- 지표가 없으면 정상으로 본다(`saga_failed_total` 은 실패 전까지 없음). 첫 실패도 잡으려고 `increase` 대신 5분 전 값과 뺀다
- 로그 기반 규칙은 코드 · 라이브러리의 로그 문구를 찾는다 → 문구를 바꾸면 `rules-logs.yaml` 도 같이. 1분마다 조회(Loki 메모리가 작음)
