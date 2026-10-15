# AWS Load Balancer Controller Helm 설치(차트 3.5.0) + IRSA sesac-gojigi-lbc-irsa (iam_policy.json = 같은 버전 공식 정책 파일)

# 공식 정책 파일 — LBC v3.5.0 docs/install/iam_policy.json (차트 버전을 올리면 같은 버전 파일로 교체)
resource "aws_iam_policy" "lbc" {
  name        = "sesac-gojigi-lbc-policy"
  description = "AWS Load Balancer Controller (v3.5.0 공식 정책)"
  policy      = file("${path.module}/iam_policy.json")
}

module "lbc_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name        = "sesac-gojigi-lbc-irsa"
  role_policy_arns = { lbc = aws_iam_policy.lbc.arn }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# gateway Service(type LoadBalancer) → NLB + EIP 어노테이션을 처리하는 컨트롤러
resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lbc_chart_version
  namespace  = "kube-system"

  values = [yamlencode({
    clusterName = module.eks.cluster_name
    region      = var.aws_region
    vpcId       = data.terraform_remote_state.vpc.outputs.vpc_id # IMDS 조회 대신 명시
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = module.lbc_irsa.iam_role_arn
      }
    }
    nodeSelector = { tier = "app" } # db 노드(테인트)에는 어차피 못 뜨지만 명시
  })]

  # 노드 · coredns 가 준비된 뒤 설치
  # 근본 원인: EKS 1.35 기본 metrics-server v0.9.0 이 protobuf /openapi/v2 를 503 으로 만듦 → metrics-server.tf 에서 v0.8.1 고정(이슈 #11).
  # 아래 설정은 같은 증상의 이전 우회책 — 안전장치로 유지. (당시 기록) /openapi 조회 실패로 Helm 의 스키마 검증이
  # "unable to build kubernetes objects ... the server is currently unable to handle the request" 로 실패한다 (10/14 재현).
  # 공식 차트라 스키마 검증 생략 위험이 작다 — 실제 적용은 API 서버가 검증한다
  disable_openapi_validation = true

  # 노드 · coredns(module.eks) 와 metrics-server 애드온 완료 뒤 — API 탐색 중 집계 API 가 바뀌지 않게
  depends_on = [module.eks, aws_eks_addon.metrics_server]
}
