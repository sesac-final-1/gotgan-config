#!/bin/bash
# MySQL 최초 기동 시 1회 — 서비스별 스키마 · 계정 · 권한 (가이드라인 06장). docker-compose 와 클러스터가 같은 스크립트를 쓴다.
# .sql 파일은 환경 변수를 치환하지 못하므로 .sh 로 작성한다.
# *_DB_PASSWORD 는 K8s Secret mysql-secret(← GitHub Secrets, secrets-sync 워크플로) 에서 mysql 컨테이너 환경 변수로 주입된다.
# MySQL 시간대는 StatefulSet / docker-compose 의 --default-time-zone=+09:00 으로 고정 (JDBC · JVM 도 Asia/Seoul)
set -e
for svc in user store product order payment review settlement keycloak; do
  pw_var="$(echo "$svc" | tr a-z A-Z)_DB_PASSWORD"
  mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<SQL
CREATE DATABASE IF NOT EXISTS ${svc}db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${svc}'@'%' IDENTIFIED BY '${!pw_var}';
GRANT ALL PRIVILEGES ON ${svc}db.* TO '${svc}'@'%';
SQL
done
# gateway · admin 은 DB 없음. keycloakdb 는 Keycloak 이 관리 (우리 Flyway · 컨벤션 대상 아님)
