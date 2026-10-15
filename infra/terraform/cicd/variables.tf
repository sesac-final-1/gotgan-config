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
  # GitHub 저장소 OIDC 설정이 immutable subject(use_immutable_subject = true) — sub 가 이름 대신 `소유자@ID/저장소@ID` 형식
  #   (저장소를 지우고 같은 이름으로 다시 만들어도 ID 가 달라 역할을 넘겨받지 못함). 확인: gh api repos/sesac-final-1/{저장소}/actions/oidc/customization/sub
  default = [
    "repo:sesac-final-1@341724939/gotgan-config@1416543587:ref:refs/heads/main",  # infra-schedule · bootstrap · secrets-sync · workflow_dispatch
    "repo:sesac-final-1@341724939/gotgan-config@1416543587:pull_request",         # infra.yml PR plan
    "repo:sesac-final-1@341724939/gotgan-backend@1416543417:ref:refs/heads/main", # backend.yml ECR push · serverless.yml — 둘 다 main push 에서만 AWS 사용
  ]
}

variable "max_session_duration" {
  description = "역할 세션 최대 시간(초) — cluster apply · destroy 가 1시간을 넘을 수 있어 2시간"
  type        = number
  default     = 7200
}
