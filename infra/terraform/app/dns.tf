# API 공개 주소 api.{domain_name} — Route 53 A 레코드(EIP 2개) + ACM 인증서(DNS 검증) → gateway NLB 443 TLS 리스너 (DuckDNS 대체)
# 도메인은 Route 53 에서 등록(호스팅 영역 자동 생성) → 여기서는 영역을 data 로 찾기만 한다 (영역을 새로 만들면 등록 기관 NS 와 어긋남)
# domain_name 이 비어 있으면 아무것도 만들지 않는다 — 도메인 구입 전에도 plan · apply 가 무변경
# 상시 폴더라 매일 NLB 가 다시 생겨도 레코드 · 인증서는 그대로 (EIP 가 고정이라 DNS 변경 없음)

locals {
  api_dns_enabled = var.domain_name != ""
  api_host        = "api.${var.domain_name}"
}

data "aws_route53_zone" "main" {
  count = local.api_dns_enabled ? 1 : 0
  name  = var.domain_name
}

# NLB 의 두 EIP 를 모두 가리킨다 — 한 AZ 가 죽어도 다른 IP 로 접속 (DuckDNS 는 [0] 하나만 가능했음)
resource "aws_route53_record" "api" {
  count   = local.api_dns_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = local.api_host
  type    = "A"
  ttl     = 300
  records = aws_eip.nlb[*].public_ip
}

# NLB 와 같은 리전(ap-northeast-2) 인증서 — 공인 인증서는 무료, 갱신은 ACM 이 자동 (DNS 검증 레코드가 남아 있는 한)
resource "aws_acm_certificate" "api" {
  count             = local.api_dns_enabled ? 1 : 0
  domain_name       = local.api_host
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "api_cert_validation" {
  for_each = local.api_dns_enabled ? {
    for o in aws_acm_certificate.api[0].domain_validation_options : o.domain_name => o
  } : {}

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  ttl     = 300
  records = [each.value.resource_record_value]
}

resource "aws_acm_certificate_validation" "api" {
  count                   = local.api_dns_enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.api[0].arn
  validation_record_fqdns = [for r in aws_route53_record.api_cert_validation : r.fqdn]
}
