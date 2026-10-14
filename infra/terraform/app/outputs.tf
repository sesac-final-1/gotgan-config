# 다른 폴더 · 사람이 쓸 값 — terraform_remote_state 로 읽힌다. S3 · SQS · SNS ARN → cluster/irsa.tf · EIP allocation ID → Helm values(gateway NLB) · 공인 IP → DuckDNS

output "nlb_eip_allocation_ids" {
  description = "NLB 용 EIP allocation ID [2a, 2c] — Helm values gateway Service 어노테이션 aws-load-balancer-eip-allocations"
  value       = aws_eip.nlb[*].id
}

output "nlb_eip_public_ips" {
  description = "NLB 용 공인 IP [2a, 2c] — [0] 을 DuckDNS(gotgan-api) 에 등록"
  value       = aws_eip.nlb[*].public_ip
}
