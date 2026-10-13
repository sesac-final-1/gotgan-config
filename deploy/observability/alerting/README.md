# 알림 규칙 (담당 박지연)

Grafana Alerting → Discord/Slack 웹훅 (웹훅 URL 은 Secret 으로, 커밋 금지)

1. 5분간 5xx 비율 > 5%
2. 파드 재시작 증가 (OOMKilled 의심)
3. saga 보상 또는 DLQ 메시지 발생
4. 서비스 다운 — 가용 레플리카 0 (System Status 와 연동)
