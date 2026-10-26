# NLB 용 EIP 2개 (API 공개 주소 api.gotgan.click 이 가리키는 고정 IP — dns.tf A 레코드, 가이드라인 05장) → Helm values 의 gateway NLB 어노테이션
# 태그 Name = sesac-gojigi-nlb-eip-0 · -1 (count.index). A 레코드는 두 IP 를 모두 가리킨다

# 퍼블릭 서브넷(2a, 2c)마다 하나씩 — NLB 를 다시 만들어도(매일 08:00) 이 IP 는 유지된다
# 순서 = vpc output public_subnets 의 AZ 순서 [2a, 2c] — 어노테이션의 서브넷 · EIP 목록 순서를 맞출 것
resource "aws_eip" "nlb" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "sesac-gojigi-nlb-eip-${count.index}" # -0 = 2a, -1 = 2c
  }
}
