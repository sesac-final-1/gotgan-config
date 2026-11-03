#!/usr/bin/env bash
# 측정 중 DB · Redis · 파드 기록 — 10초마다 CSV 한 줄 (조회만). exporter 가 없는 MySQL 연결 수 · Redis 메모리를 Prometheus 대신 여기서. 담당 구지훈
#   bash loadtest/watch-db.sh s1-browse          # Ctrl+C 로 끝 — 끝날 때 MySQL 쿼리 상위 5개(실행 횟수 · 총 시간 · 훑은 행)를 함께 저장
#   RESET=1 bash loadtest/watch-db.sh s1-browse  # 시작 전에 쿼리 통계(performance_schema 요약)를 비움 — 그 시나리오 쿼리만 보이게
# 비밀번호는 파드 환경 변수에서 파드 안에서만 읽고 출력하지 않는다
set -u
NAME=${1:-run}
NS=sesac-gojigi
OUT=loadtest/results
mkdir -p "$OUT"
STAMP=$(date +%Y%m%d-%H%M%S)
CSV="$OUT/watch-$NAME-$STAMP.csv"
TOP="$OUT/top-queries-$NAME-$STAMP.tsv"

mysql() { kubectl -n "$NS" exec mysql-0 -- sh -c "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" -N -B -e \"$1\" 2>/dev/null"; }
redis() { kubectl -n "$NS" exec redis-0 -- redis-cli INFO "$1" 2>/dev/null | tr -d '\r'; }

if [ "${RESET:-0}" = 1 ]; then
  mysql "TRUNCATE TABLE performance_schema.events_statements_summary_by_digest" && echo "쿼리 통계 초기화"
fi

echo "time,threads_connected,max_used_connections,aborted_connects,threads_running,redis_used_mb,redis_ops_per_sec,redis_clients,pods_cpu_m,pods_mem_mi" > "$CSV"
finish() {
  mysql "SELECT LEFT(DIGEST_TEXT, 160), COUNT_STAR, ROUND(SUM_TIMER_WAIT/1e12, 2) AS total_s, ROUND(AVG_TIMER_WAIT/1e9, 2) AS avg_ms, SUM_ROWS_EXAMINED
         FROM performance_schema.events_statements_summary_by_digest WHERE SCHEMA_NAME LIKE '%db' ORDER BY SUM_TIMER_WAIT DESC LIMIT 5" > "$TOP"
  echo; echo "기록: $CSV · 쿼리 상위 5: $TOP"
  exit 0
}
trap finish INT TERM

echo "기록 시작 — $CSV (Ctrl+C 로 끝)"
while true; do
  status=$(mysql "SHOW GLOBAL STATUS WHERE Variable_name IN ('Threads_connected','Max_used_connections','Aborted_connects','Threads_running')" | awk '{v[$1]=$2} END {print v["Threads_connected"]","v["Max_used_connections"]","v["Aborted_connects"]","v["Threads_running"]}')
  mem=$(redis memory | awk -F: '/^used_memory:/ {printf "%.1f", $2/1048576}')
  stats=$(redis stats | awk -F: '/^instantaneous_ops_per_sec:/ {print $2}')
  clients=$(redis clients | awk -F: '/^connected_clients:/ {print $2}')
  pods=$(kubectl -n "$NS" top pods --no-headers 2>/dev/null | awk '{gsub("m","",$2); gsub("Mi","",$3); c+=$2; m+=$3} END {print c","m}')
  line="$(date +%H:%M:%S),$status,$mem,$stats,$clients,$pods"
  echo "$line" >> "$CSV"
  echo "$line"
  sleep 10
done
