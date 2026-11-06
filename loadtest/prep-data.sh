#!/usr/bin/env bash
# 측정 직전 데이터 준비 — 시드는 매일 08:00 새로 만들어지므로 측정하는 날 한 번 (공지 뒤 실행). 담당 구지훈
#   bash loadtest/prep-data.sh stock        # S3 · S7 부하용 옵션 재고 100,000 · S4 옵션 10201 재고 10
#   bash loadtest/prep-data.sh settlement   # S6 정산 대상 5,000건 — 지난주 구매확정분
#   bash loadtest/prep-data.sh status       # 지금 값만 조회
# settlement: 스토어 1(산골농부 · SES 인증 주소)에 2,500건 → 지급 때 항목 압축(itemsGzip) 경로,
#             나머지 7개 스토어에 약 357건씩 → 아웃박스 64KB 를 넘는 평문 경로. 둘 다 11/5 수정(backend #240) 확인용
# 비밀번호는 파드 환경 변수에서 파드 안에서만 읽고 출력하지 않는다
set -eu
NS=sesac-gojigi
OPTS=$(sed -n '/export const ORDER_OPTIONS/,/\];/p' loadtest/k6/lib.js | grep -oE '[0-9]{5,6}' | tr '\n' ',' | sed 's/,$//')

sql() { kubectl -n "$NS" exec -i mysql-0 -- sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -t 2>&1 | grep -v "Using a password"'; }

status() {
  sql <<EOF
SELECT 'S3 · S7 옵션' AS what, COUNT(*) AS cnt, MIN(stock) AS min_stock FROM productdb.product_option WHERE product_option_id IN ($OPTS)
UNION ALL SELECT 'S4 옵션 10201', 1, stock FROM productdb.product_option WHERE product_option_id = 10201
UNION ALL SELECT '정산 대상(미집계)', COUNT(*), NULL FROM settlementdb.settlement_item WHERE settlement_id IS NULL
UNION ALL SELECT '부하용 계정', COUNT(*), NULL FROM userdb.users WHERE email LIKE 'loadtest+%';
EOF
}

case "${1:-}" in
  stock)
    sql <<EOF
UPDATE productdb.product_option SET stock = 100000 WHERE product_option_id IN ($OPTS);
UPDATE productdb.product_option SET stock = 10 WHERE product_option_id = 10201;
EOF
    status ;;
  settlement)
    # 지난주 월요일 00:00(KST) 부터 2분 간격 — 5,000건이 그 주 안에 들어간다
    sql <<'EOF'
SET SESSION cte_max_recursion_depth = 6000;
SET @week_start = DATE_SUB(CURDATE(), INTERVAL (WEEKDAY(CURDATE()) + 7) DAY);
INSERT INTO settlementdb.settlement_item (order_item_id, order_no, store_id, product_id, product_name, category_id, item_amt, commission_rate, commission_amt, payment_fee_amt, confirmed_at)
WITH RECURSIVE s(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM s WHERE n < 5000),
 t AS (SELECT n, IF(n % 2 = 0, 1, ELT(1 + (n DIV 2) % 7, 2, 11, 12, 13, 17, 18, 19)) AS store_id, 20000 + (n * 37) % 80000 AS amt FROM s)
SELECT 9000000 + n, CONCAT('LOAD-', LPAD(n, 8, '0')), store_id, store_id * 100 + 1, CONCAT('부하 상품 ', store_id), 1 + n % 3, amt, 7.00, FLOOR(amt * 0.07), FLOOR(amt * 0.022),
  TIMESTAMP(@week_start) + INTERVAL (n * 120) SECOND FROM t;
SELECT store_id, COUNT(*) AS items FROM settlementdb.settlement_item WHERE order_item_id >= 9000000 GROUP BY store_id;
EOF
    status ;;
  status) status ;;
  *) echo "usage: $0 stock | settlement | status"; exit 1 ;;
esac
