# 입력 변수 — snake_case + description 필수 (컨벤션 5-2)

variable "aws_region" {
  description = "AWS 리전 (서울)"
  type        = string
  default     = "ap-northeast-2"
}

variable "services" {
  description = "ECR 저장소를 만들 서비스 이름 — 저장소 이름은 sesac-gojigi-{서비스} (backend.yml REPOSITORY · Helm values repository 와 같다)"
  type        = set(string)
  default     = ["gateway", "user", "store", "product", "order", "settlement", "payment", "review", "admin"]
}

variable "keep_image_count" {
  description = "저장소마다 남길 최근 이미지 수 — 넘으면 오래된 것부터 자동 삭제"
  type        = number
  default     = 10
}
