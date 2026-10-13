# Grafana 대시보드 (담당 박지연)

JSON 으로 내보내 여기에 커밋하고 ConfigMap 으로 프로비저닝 — 클러스터를 다시 만들어도 복원된다.

| 파일 | 내용 | 근거 |
|---|---|---|
| `system-status.json` | **헬스 체크 대시보드** — 서비스별 Stat(가용/원하는 레플리카 → 초록 · 노랑 · 빨강) · State timeline(`up` · 파드 Ready, 최근 30분) · 롤링 배포 패널 · 파드 재시작 수 · 입구 생존(gateway `up` Stat). 데이터는 Prometheus `up` · kube-state-metrics 만 — blackbox exporter 없음(10/13 3차) | 가이드라인 13장 |
| `services.json` | RED — 서비스별 요청 수 · 5xx 비율 · p95 지연 | 13장 |
| `jvm.json` | 힙 · GC · 스레드 · 재시작 | 13장 |
| `saga.json` | 분당 주문 · 결제 실패 · saga 보상 · DLQ 적재 수 | 13장 |
| `cluster.json` | 노드 · 파드 CPU/메모리 | 13장 |
