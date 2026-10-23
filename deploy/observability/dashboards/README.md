# Grafana 대시보드 (담당 박지연)

JSON 으로 내보내 여기에 커밋하고 ConfigMap 으로 프로비저닝 — 클러스터를 다시 만들어도 복원된다.

| 파일 | 내용 | 근거 |
|---|---|---|
| `system-status.json` | **헬스 체크 대시보드** — 서비스별 Stat(가용/원하는 레플리카 → 초록 · 노랑 · 빨강) · State timeline(`up` · 파드 Ready, 최근 30분) · 롤링 배포 패널 · 파드 재시작 수 · 입구 생존(gateway `up` Stat). 데이터는 Prometheus `up` · kube-state-metrics 만 — blackbox exporter 없음(10/13 3차) | 가이드라인 13장 |
| `logs.json` | **로그 대시보드** — `$app`(서비스) · `$level` · 검색어 · traceId · userId 로 골라 보기. 레벨별 로그량 · 서비스별 ERROR · WARN/ERROR 많이 낸 로거 Top 10 · 응답 오류 코드 Top 10 · 로그 목록 · 사용자 한 명의 요청. 기본 1시간 | 10/22 노션 로깅 공유 4절 |
| `services.json` | RED — 서비스별 요청 수 · 5xx 비율 · p95 지연 | 13장 |
| `jvm.json` | 힙 · GC · 스레드 · 재시작 | 13장 |
| `saga.json` | 분당 주문 · 결제 실패 · saga 보상 · DLQ 적재 수 | 13장 |
| `cluster.json` | 노드 · 파드 CPU/메모리 | 13장 |

## 추가 · 수정 · 반영

- 올리는 방법: bootstrap 이 이 폴더를 `grafana-dashboards` ConfigMap 으로 만든다(`--from-file`, 이 README 도 들어가지만 Grafana 는 `.json` 만 읽음) → `grafana.yaml` provider 가 `/etc/grafana/dashboards` 에서 등록
- 화면에서 만든 · 고친 대시보드는 Grafana 가 다시 뜨면 사라진다(emptyDir) → 오른쪽 위 Export → JSON 으로 내보내 여기 커밋. 데이터소스는 uid(`prometheus` · `loki` · `zipkin`)로 지정
- 낮에 클러스터에서 바로 확인할 때:

```bash
kubectl create configmap grafana-dashboards -n monitoring --from-file=deploy/observability/dashboards/ --dry-run=client -o yaml | kubectl apply --server-side -f -
kubectl rollout restart deploy/grafana -n monitoring   # 기존 파일을 고쳤을 때만 필요 — 새 파일은 1분 안에 자동 등록
```

- ConfigMap 은 1MiB 까지 — 대시보드가 많이 늘면 나눠야 함
