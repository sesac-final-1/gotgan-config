# terraform {} 블록 — required_version "~> 1.16.0"(팀 · CI 모두 1.16.5 고정 — use_lockfile 은 1.10+ 필요) · aws provider ~> 5.0 (모듈 vpc ~> 5 · eks ~> 20 과 호환) · backend "s3" (상태 버킷 sesac-gojigi-tfstate-<계정4>, key = "ecr/terraform.tfstate", 잠금 use_lockfile)
# provider "aws" — region ap-northeast-2 · default_tags { Project = "sesac-gojigi", ManagedBy = "terraform" } (컨벤션 5-1)
# 계정 ID · 리전 하드코딩 금지 — data.aws_caller_identity · 변수 사용 (예외: backend 블록은 변수를 못 쓰므로 버킷 이름을 그대로 적는다). 담당 구지훈
