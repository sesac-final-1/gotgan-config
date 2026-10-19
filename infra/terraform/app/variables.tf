# 입력 변수 — snake_case + description 필수 (컨벤션 5-2)

variable "aws_region" {
  description = "AWS 리전 (서울)"
  type        = string
  default     = "ap-northeast-2"
}

variable "cors_allowed_origins" {
  description = "presigned PUT 업로드를 허용할 브라우저 출처 — 운영(Vercel) · 미리보기(*.vercel.app) · 로컬 Vite"
  type        = list(string)
  default     = ["https://gotgan.vercel.app", "https://*.vercel.app", "http://localhost:5173"]
}

variable "log_archive_glacier_days" {
  description = "log-archive 버킷 객체를 Glacier 로 옮기는 일수"
  type        = number
  default     = 90
}

variable "ses_sender_email" {
  description = "SES 발신 주소(From) — 알림 · 정산 명세서 메일. 샌드박스라 인증 메일의 링크를 눌러야 발송 가능"
  type        = string
  default     = "wlsgksvheh@gmail.com"
}

variable "ses_recipient_emails" {
  description = "샌드박스 수신자로 추가 인증할 주소 (팀원 · 시연 계정). 발신 주소는 자동 포함"
  type        = list(string)
  default     = []
}

variable "domain_name" {
  description = "API 공개 도메인 (Route 53 에서 등록한 도메인, 예: gotgan.click) — 비어 있으면 DNS · 인증서를 만들지 않는다 (dns.tf)"
  type        = string
  default     = ""
}
