# 다른 폴더 · 사람이 쓸 값 — terraform_remote_state 로 읽힌다. S3 · SQS · SNS ARN → cluster/irsa.tf · EIP allocation ID → Helm values(gateway NLB) · 공인 IP → DuckDNS

output "nlb_eip_allocation_ids" {
  description = "NLB 용 EIP allocation ID [2a, 2c] — Helm values gateway Service 어노테이션 aws-load-balancer-eip-allocations"
  value       = aws_eip.nlb[*].id
}

output "nlb_eip_public_ips" {
  description = "NLB 용 공인 IP [2a, 2c] — [0] 을 DuckDNS(gotgan-api) 에 등록"
  value       = aws_eip.nlb[*].public_ip
}

output "bucket_names" {
  description = "S3 버킷 이름 (용도 → 이름) — 서비스 ConfigMap · presign 대상"
  value       = { for k, b in aws_s3_bucket.this : k => b.bucket }
}

output "bucket_arns" {
  description = "S3 버킷 ARN (용도 → ARN) — cluster/irsa.tf 권한 대상"
  value       = { for k, b in aws_s3_bucket.this : k => b.arn }
}

output "images_base_url" {
  description = "이미지 공개 URL 앞부분 — {base}/products/{key} · {base}/reviews/{key}"
  value       = "https://${aws_s3_bucket.this["images"].bucket_regional_domain_name}"
}

output "topic_arns" {
  description = "SNS 토픽 ARN (도메인 → ARN) — 발행 서비스 ConfigMap · irsa.tf sns:Publish 대상"
  value       = { for k, t in aws_sns_topic.events : k => t.arn }
}

output "queue_urls" {
  description = "SQS 큐 URL (구독 이름 → URL) — 소비 서비스 ConfigMap"
  value       = { for k, q in aws_sqs_queue.this : k => q.url }
}

output "queue_arns" {
  description = "SQS 큐 ARN (구독 이름 → ARN) — cluster/irsa.tf 수신 권한 대상"
  value       = { for k, q in aws_sqs_queue.this : k => q.arn }
}

output "dynamodb_table_names" {
  description = "DynamoDB 테이블 이름"
  value       = [aws_dynamodb_table.notifications.name, aws_dynamodb_table.settlement_reports.name]
}

output "ssm_parameter_names" {
  description = "serverless.yml 이 읽는 SSM 파라미터 경로"
  value       = sort([for p in aws_ssm_parameter.this : p.name])
}
