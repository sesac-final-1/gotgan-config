# terraform {} 블록 — required_version "~> 1.16.0"(팀 · CI 모두 1.16.5 고정) · aws provider ~> 5.0 · backend 없음 (이 폴더만 로컬 상태 — 상태 버킷을 만드는 폴더라 S3 backend 를 쓸 수 없다. terraform.tfstate 는 커밋 금지 · apply 한 PC 에 보관)
# provider "aws" — region ap-northeast-2 · default_tags { Project = "sesac-gojigi", ManagedBy = "terraform" } (컨벤션 5-1)
# 계정 ID · 리전 하드코딩 금지 — data.aws_caller_identity · 변수 사용. 담당 구지훈

terraform {
  required_version = "~> 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # backend 없음 — 상태 버킷을 만드는 폴더라 로컬 상태(terraform.tfstate, gitignore)
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
