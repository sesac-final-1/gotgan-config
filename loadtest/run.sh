#!/usr/bin/env bash
# 시나리오 한 번 측정 — watch-db 를 켜고 k6(요청별 CSV · p99) → watch-db 종료(쿼리 상위 5 저장). 담당 구지훈
#   bash loadtest/run.sh s5 s5-realtime.js -e COUNT=200
# 비밀번호는 loadtest/.env(Git 제외, .env.example 참고)에서 환경 변수로 읽는다 — 명령줄 · 기록에 남지 않게
set -u
NAME=$1; SCRIPT=$2; shift 2
STAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p loadtest/results
RESET=1 bash loadtest/watch-db.sh "$NAME" > "loadtest/results/watch-$NAME-$STAMP.log" 2>&1 &
WATCH=$!
sleep 12   # 쿼리 통계 초기화 · 시작 전 기준값 한 줄
if [ -f loadtest/.env ]; then set -a; . loadtest/.env; set +a; fi
echo "시작 $(date +%H:%M:%S)"
k6 run --no-color --summary-trend-stats "avg,min,med,p(90),p(95),p(99),max" \
  --out "csv=loadtest/results/$NAME-$STAMP.csv.gz" "$@" "loadtest/k6/$SCRIPT"
CODE=$?
echo "끝 $(date +%H:%M:%S) k6 종료 코드 $CODE"
sleep 12
kill -TERM "$WATCH"   # 백그라운드 작업은 SIGINT 를 무시한다 — Ctrl+C 대신 TERM (watch-db 가 끝날 때 쿼리 상위 5 저장)
wait "$WATCH" 2>/dev/null
exit "$CODE"
