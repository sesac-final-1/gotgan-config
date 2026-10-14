# 다른 폴더 · 사람이 쓸 값 — terraform_remote_state 로 읽힌다

output "vpc_id" {
  description = "VPC ID — cluster/ (EKS 모듈 vpc_id)"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR — 보안 그룹 · NetworkPolicy 참고용"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnets" {
  description = "퍼블릭 서브넷 ID [2a, 2c] — gateway NLB 어노테이션 aws-load-balancer-subnets (EIP 순서와 같은 AZ 순서)"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "프라이빗 서브넷 ID [2a, 2c] — cluster/ 노드 그룹 (db 는 [0] = 2a 고정)"
  value       = module.vpc.private_subnets
}

output "azs" {
  description = "서브넷 AZ 순서 — public_subnets · private_subnets 인덱스와 같다"
  value       = module.vpc.azs
}

output "nat_public_ips" {
  description = "NAT 게이트웨이 공인 IP — 외부(포트원 등)가 IP 허용 목록을 요구할 때"
  value       = module.vpc.nat_public_ips
}
