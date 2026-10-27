# ECR 저장소 10개 — sesac-gojigi-gateway · sesac-gojigi-user · sesac-gojigi-store · sesac-gojigi-product · sesac-gojigi-order · sesac-gojigi-settlement · sesac-gojigi-payment · sesac-gojigi-review · sesac-gojigi-admin · sesac-gojigi-chat(10/27) + 수명주기(최근 10개). apply 순서 3
# 담당 구지훈 · 가이드라인 04장 · 스펙 03-4

resource "aws_ecr_repository" "service" {
  for_each = var.services

  name = "sesac-gojigi-${each.key}"

  # 태그는 커밋 SHA 7자리(backend.yml)라 사실상 불변이지만, CI 재실행 시 같은 태그 재push 가 막히지 않게 MUTABLE
  image_tag_mutability = "MUTABLE"

  # 발표 후 전체 destroy 때 이미지가 남아 있어도 저장소를 지울 수 있게
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true # 기본 스캔(무료) — 취약점은 콘솔에서 확인
  }
}

# 저장소마다 최근 N개만 보관 — 매 머지마다 이미지가 쌓이므로 저장 비용 관리
resource "aws_ecr_lifecycle_policy" "service" {
  for_each = aws_ecr_repository.service

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "최근 ${var.keep_image_count}개만 보관"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_image_count
      }
      action = { type = "expire" }
    }]
  })
}
