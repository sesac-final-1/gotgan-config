# VPC 모듈(terraform-aws-modules/vpc ~> 5) — 10.0.0.0/16 · 퍼블릭 /24 ×2 · 프라이빗 /24 ×2 (2a · 2c) · NAT 1 · EKS 서브넷 태그. apply 순서 2
# 담당 구지훈 · 가이드라인 04장 · 스펙 03-4

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "sesac-gojigi-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]   # NLB(EIP 2) · NAT · 작업용 EC2(선택)
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"] # EKS 노드 — app(2a · 2c) · db(2a 고정)

  # NAT 1개(2a) — AZ 장애 대비보다 비용 우선 (가이드라인 04장). VPC 엔드포인트는 두지 않음
  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # LBC 가 서브넷을 자동 탐색하는 태그 — internet-facing NLB 는 퍼블릭, 내부 LB 는 프라이빗
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
