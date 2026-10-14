# 애플리케이션이 쓰는 AWS 자원 (S3 · SNS/SQS · DynamoDB · SES · SSM · EIP) — 파일별 자원은 아래 *.tf 헤더 참고. apply 순서 4 (EIP 는 1주차, 나머지 2주차)
# IRSA 역할은 여기 없다 — cluster/irsa.tf (클러스터와 함께 매일 재생성). app/ 은 cluster 를 읽지 않는다
# 상시 유지 폴더 — 일일 destroy 대상 아님 (infra-schedule 은 cluster/ 만). 시크릿은 GitHub Secrets 단일 소스 (Secrets Manager · KMS 없음)
# 담당 구지훈 · 가이드라인 04장 · 스펙 03-4
