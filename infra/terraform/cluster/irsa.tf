# IRSA 역할은 cluster/ 에 둔다 — 신뢰 정책이 그날의 EKS OIDC 공급자를 가리키므로 클러스터와 함께 매일 재생성 (이름이 같아 Helm values 의 roleArn 은 불변). 권한 대상(S3 · SQS · SNS) 은 app/ remote state 에서 읽는다
# sesac-gojigi-{service}-irsa — user(sqs) · store(sns store-events · s3 seller-docs) · product(sqs · s3 images/products) · order(sns order-events) · review(sqs · s3 images/reviews) · settlement(sqs · sns settlement-events · s3 reports GetObject — 명세서 presign)
# gateway · payment · admin 은 IRSA 없음 (시크릿은 GitHub Secrets → secrets-sync 워크플로가 K8s Secret 으로 만든다 — KMS · Secrets Manager 권한 없음). grafana(CloudWatch 읽기)는 여기 없음 — 관측성은 박지연 담당, cluster/irsa_grafana.tf 로 별도 작성

locals {
  app_queues  = data.terraform_remote_state.app.outputs.queue_arns  # 구독 이름 → ARN
  app_topics  = data.terraform_remote_state.app.outputs.topic_arns  # store · order · settlement → ARN
  app_buckets = data.terraform_remote_state.app.outputs.bucket_arns # images · seller-docs · reports · log-archive → ARN

  sqs_consume = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]

  # 서비스 → 허용 구문 (가이드라인 04장 "서비스별 IRSA 권한"). gateway · payment · admin 은 AWS 권한 없음
  irsa_statements = {
    user = [
      { actions = local.sqs_consume, resources = [local.app_queues["user-store-events"], local.app_queues["user-order-events"]] },
    ]
    store = [
      { actions = ["sns:Publish"], resources = [local.app_topics["store"]] },
      { actions = ["s3:PutObject", "s3:GetObject"], resources = ["${local.app_buckets["seller-docs"]}/*"] }, # 입점 서류 presign
      { actions = ["s3:ListBucket"], resources = [local.app_buckets["seller-docs"]] },                       # 없는 서류 HeadObject 가 403 대신 404 가 되게 (S3 는 ListBucket 없으면 존재 여부를 숨김)
      { actions = ["s3:PutObject"], resources = ["${local.app_buckets["images"]}/stores/*"] },               # 스토어 대표 이미지 presigned PUT (STR-06)
    ]
    product = [
      { actions = local.sqs_consume, resources = [local.app_queues["product-store-events"]] },
      { actions = ["s3:PutObject"], resources = ["${local.app_buckets["images"]}/products/*"] }, # 상품 이미지 presigned PUT
    ]
    order = [
      { actions = ["sns:Publish"], resources = [local.app_topics["order"]] },
    ]
    review = [
      { actions = local.sqs_consume, resources = [local.app_queues["review-order-events"]] },
      { actions = ["s3:PutObject"], resources = ["${local.app_buckets["images"]}/reviews/*"] }, # 리뷰 이미지 presigned PUT
    ]
    settlement = [
      { actions = local.sqs_consume, resources = [local.app_queues["settlement-store-events"], local.app_queues["settlement-order-events"]] },
      { actions = ["sns:Publish"], resources = [local.app_topics["settlement"]] },
      { actions = ["s3:GetObject"], resources = ["${local.app_buckets["reports"]}/*"] }, # 명세서 presigned 링크
      { actions = ["s3:ListBucket"], resources = [local.app_buckets["reports"]] },       # CSV 생성 전 HeadObject 가 403 대신 404 → 409 SETTLE_REPORT_NOT_READY
    ]
  }
}

resource "aws_iam_policy" "service" {
  for_each = local.irsa_statements

  name        = "sesac-gojigi-${each.key}-irsa-policy"
  description = "${each.key}-service 최소 권한 (IRSA)"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [for s in each.value : { Effect = "Allow", Action = s.actions, Resource = s.resources }]
  })
}

# 역할 이름 고정 → ARN 불변 (Helm values roleArn). 신뢰 정책은 그날의 OIDC 공급자 — 클러스터와 함께 매일 재생성
module "service_irsa" {
  source   = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version  = "~> 5.0"
  for_each = local.irsa_statements

  role_name        = "sesac-gojigi-${each.key}-irsa"
  role_policy_arns = { main = aws_iam_policy.service[each.key].arn }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["sesac-gojigi:${each.key}-service"] # Helm serviceaccount.yaml: 이름 = 서비스 키
    }
  }
}
