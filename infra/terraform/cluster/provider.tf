# terraform {} 블록 — required_version "~> 1.16.0"(팀 · CI 모두 1.16.5 고정 — use_lockfile 은 1.10+ 필요) · aws provider ~> 5.0 (모듈 vpc ~> 5 · eks ~> 20 과 호환) · backend "s3" (상태 버킷 sesac-gojigi-tfstate-<계정4>, key = "cluster/terraform.tfstate", 잠금 use_lockfile)
# provider "aws" — region ap-northeast-2 · default_tags { Project = "sesac-gojigi", ManagedBy = "terraform" } (컨벤션 5-1)
# 계정 ID · 리전 하드코딩 금지 — data.aws_caller_identity · 변수 사용 (예외: backend 블록은 변수를 못 쓰므로 버킷 이름을 그대로 적는다). 담당 구지훈

terraform {
  required_version = "~> 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17" # 3.x 는 kubernetes 블록 문법이 바뀜 — 2.x 고정
    }
  }

  # backend 블록은 변수를 쓸 수 없어 버킷 이름만 하드코딩 예외 (컨벤션 5-2)
  backend "s3" {
    bucket       = "sesac-gojigi-tfstate-4380"
    key          = "cluster/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "sesac-gojigi"
      ManagedBy = "terraform"
    }
  }
}

# LBC Helm 설치용 — 토큰은 실행 시점에 aws CLI 로 받는다 (로컬 · Actions 러너 모두 aws CLI 있음)
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}
