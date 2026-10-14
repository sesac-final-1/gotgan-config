# SES 발신 주소 · 도메인 자격 증명 (샌드박스 — 수신자도 검증 필요)

# 샌드박스: 발신 · 수신 주소 모두 인증 필요. apply 하면 각 주소로 인증 메일이 가고, 링크를 눌러야 Verified
resource "aws_sesv2_email_identity" "this" {
  for_each = toset(concat([var.ses_sender_email], var.ses_recipient_emails))

  email_identity = each.value
}
