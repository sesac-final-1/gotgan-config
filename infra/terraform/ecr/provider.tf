# terraform {} 블록 — required_version · aws provider ~> 5.0 (모듈 vpc ~> 5 · eks ~> 20 과 호환) · backend "s3" (상태 버킷 sesac-gojigi-tfstate-<계정4>, key = "ecr/terraform.tfstate", 잠금 use_lockfile)
# provider "aws" — region ap-northeast-2 · default_tags { Project = "sesac-gojigi", ManagedBy = "terraform" } (컨벤션 5-1)
# 계정 ID · 리전 하드코딩 금지 — data.aws_caller_identity · 변수 사용. 담당 구지훈
