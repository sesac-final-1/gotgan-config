# 입력 변수 — snake_case + description 필수 (컨벤션 5-2)

variable "aws_region" {
  description = "AWS 리전 (서울)"
  type        = string
  default     = "ap-northeast-2"
}
