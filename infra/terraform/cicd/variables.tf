# 입력 변수 — snake_case + description 필수 (컨벤션 5-2)

variable "aws_region" {
  description = "AWS 리전 (서울)"
  type        = string
  default     = "ap-northeast-2"
}

variable "github_actions_role_name" {
  description = "GitHub Actions 가 OIDC 로 넘겨받는 역할 이름 — cluster/ 가 이 이름으로 조회해 access_entries 에 넣으므로 바꾸면 안 됨"
  type        = string
  default     = "sesac-gojigi-github-actions"
}

variable "github_oidc_subjects" {
  description = "역할을 넘겨받을 수 있는 워크플로 — 토큰의 sub 클레임 (StringLike). 목록에 없는 저장소 · 브랜치 · 이벤트는 AssumeRole 에서 거부"
  type        = list(string)
  default = [
    "repo:sesac-final-1/gotgan-config:ref:refs/heads/main",  # infra-schedule · bootstrap · secrets-sync · workflow_dispatch
    "repo:sesac-final-1/gotgan-config:pull_request",         # infra.yml PR plan
    "repo:sesac-final-1/gotgan-backend:ref:refs/heads/main", # backend.yml ECR push · serverless.yml — 둘 다 main push 에서만 AWS 사용
  ]
}

variable "max_session_duration" {
  description = "역할 세션 최대 시간(초) — cluster apply · destroy 가 1시간을 넘을 수 있어 2시간"
  type        = number
  default     = 7200
}
