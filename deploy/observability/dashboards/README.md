# Grafana 대시보드 (담당 박지연)

JSON 으로 내보내 여기에 커밋하고 ConfigMap 으로 프로비저닝 — 클러스터를 다시 만들어도 복원된다.

| 파일 | 내용 | 근거 |
|---|---|---|
| `system-status.json` | **헬스 체크 대시보드** — 서비스별 Stat(가용/원하는 레플리카 → 초록 · 노랑 · 빨강) · State timeline(`up` · 파드 Ready, 최근 30분) · 롤링 배포 패널 · 파드 재시작 수 · Gateway 상태(gateway `up` Stat) · 서비스별 5xx · 서킷 OPEN 수 · 서킷 상태(호출 서비스 → 대상) · 서킷 실패율(쿼리 출처 grafana.com 21307). 데이터는 Prometheus `up` · kube-state-metrics · Micrometer 만 — blackbox exporter 없음(10/13 3차) | 가이드라인 13장 |
| `logs.json` | **로그 대시보드** — `$app`(서비스) · `$level` · 검색어 · traceId · userId 로 골라 보기. 레벨별 로그량 · 서비스별 ERROR · WARN/ERROR 많이 낸 로거 Top 10 · 응답 오류 코드 Top 10 · 로그 목록 · 사용자 한 명의 요청. 기본 1시간 | 10/22 노션 로깅 공유 4절 |
| `services.json` | **서비스 (RED)** — 요약 Stat(게이트웨이 기준 RPS · 에러율 (5xx) · 요청 제한 (429) · 평균 · p95 응답 시간) · 서비스별 RPS · 에러율 (5xx) · p95 · 평균 · 최대 응답 시간(선 → Logs 링크) · 느린 API · 오류 많은 API Top 10 · 게이트웨이 라우트별 RPS · **429** · p95 · 채팅 WebSocket 세션. `$app` 다중 선택, `/actuator` 제외. p95 는 backend slo 구간 8개(`_bucket`)로 계산 — backend 배포 전에는 비어 있음 | 13장 · 노션 11/02 게이트웨이 요청 제한 |
| `jvm.json` | **JVM · 자원 (측정용)** — k6 부하 측정 때 한 화면에서: 요약 Stat(DB 커넥션 수 (전체) / 151 · 메모리 사용률 (최대) · Pending 커넥션 (최대) · 재시작 (1h) · OOMKilled · 노드 CPU (최대)) · 메모리 사용률 (limit 대비) · Heap 사용률 · Non-heap 메모리 · Old Gen 사용률 (GC 후) · GC Pause 비율 · 최대 · Active · Pending 커넥션 · 커넥션 획득 시간 · Timeout · CPU 사용률 (requests 대비) · 노드 CPU · Live 스레드. `$app` 다중 선택. 쿼리는 grafana.com 4701 · 12900 · 15760 을 우리 라벨로 옮김(CPU limit 없어 throttling 패널 없음) | 13장 · 11/2 확장계획 5-5 |
| `saga.json` | 분당 주문 · 결제 실패 · saga 보상 · DLQ 적재 수 | 13장 |
| `cluster.json` | **클러스터** — 요약 Stat(노드 수 · NotReady 노드 · 노드 CPU · 메모리 최대 · 메모리 requests 최대 · 비정상 파드) · 노드별 CPU · 메모리 사용률 · CPU · 메모리 requests 비율 · 실행 중 파드 수 · 파드별 CPU · 메모리 · 파드 배치 표 · 네임스페이스별 CPU · 메모리 · 컨테이너 재시작 · 파드 상태 사유. `$namespace` 는 파드 패널에만 적용. node-exporter 없이 cAdvisor(`id="/"`) · kube-state-metrics 로 계산, 네임스페이스 패널 쿼리는 grafana.com 15757 을 우리 라벨로 옮김 | 13장 |

## 추가 · 수정 · 반영

- 올리는 방법: bootstrap 이 이 폴더를 `grafana-dashboards` ConfigMap 으로 만든다(`--from-file`, 이 README 도 들어가지만 Grafana 는 `.json` 만 읽음) → `grafana.yaml` provider 가 `/etc/grafana/dashboards` 에서 등록
- 화면에서 만든 · 고친 대시보드는 Grafana 가 다시 뜨면 사라진다(emptyDir) → 오른쪽 위 Export → JSON 으로 내보내 여기 커밋. 데이터소스는 uid(`prometheus` · `loki` · `zipkin`)로 지정
- 낮에 클러스터에서 바로 확인할 때:

```bash
kubectl create configmap grafana-dashboards -n monitoring --from-file=deploy/observability/dashboards/ --dry-run=client -o yaml | kubectl apply --server-side -f -
kubectl rollout restart deploy/grafana -n monitoring   # 기존 파일을 고쳤을 때만 필요 — 새 파일은 1분 안에 자동 등록
```

- ConfigMap 은 1MiB 까지 — 대시보드가 많이 늘면 나눠야 함
