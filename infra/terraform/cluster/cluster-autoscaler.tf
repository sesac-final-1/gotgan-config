# Cluster Autoscaler Helm 설치(차트 9.59.0 = CA 1.35.0, 클러스터 1.35 와 같은 마이너) + IRSA sesac-gojigi-cluster-autoscaler-irsa (11/17)
# 24시간 운영, 비용 제약이 풀려 추가 — 파드가 자리가 없어 Pending 이면 app 노드를 늘리고(최대 3대), 한가하면 2대로 줄인다.
# app 노드그룹만 맡긴다(db 노드그룹은 MySQL, Redis PV 가 있어 손대지 않음) — ASG 이름을 직접 주고 최소 2대(노드 하나가 죽어도 구매 경로 유지).
# ASG 의 min_size 0 은 그대로(scripts/scale-nodes.sh 수동 보조용) — CA 는 자기 설정의 최소 2대 아래로 줄이지 않는다.
# HPA(Helm values hpa)가 파드를 늘리고, 노드가 모자라면 CA 가 노드를 늘린다. 지금은 노드 2대 요청 합이 CPU 51~56%, 메모리 36~44% 라 보통은 노드가 늘지 않는다

module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                        = "sesac-gojigi-cluster-autoscaler-irsa"
  attach_cluster_autoscaler_policy = true # ASG 조회, desired 변경 — 이 클러스터 태그가 붙은 ASG 만
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.cluster_autoscaler_chart_version
  namespace  = "kube-system"

  values = [yamlencode({
    cloudProvider = "aws"
    awsRegion     = var.aws_region
    autoscalingGroups = [for asg in module.eks.eks_managed_node_groups["app"].node_group_autoscaling_group_names : {
      name    = asg
      minSize = 2
      maxSize = 3
    }]
    rbac = {
      serviceAccount = {
        create = true
        name   = "cluster-autoscaler"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.cluster_autoscaler_irsa.iam_role_arn
        }
      }
    }
    extraArgs = {
      "balance-similar-node-groups"   = true
      "skip-nodes-with-local-storage" = false # 관측성 emptyDir 때문에 노드를 못 줄이는 일이 없게(데이터는 PVC)
      "scale-down-unneeded-time"      = "10m"
      "expander"                      = "least-waste"
    }
    nodeSelector = { tier = "app" }
    resources = {
      requests = { cpu = "50m", memory = "128Mi" }
      limits   = { memory = "256Mi" }
    }
  })]

  disable_openapi_validation = true # lbc.tf 와 같은 이유(EKS 1.35 /openapi 503 이전 우회책 유지)

  depends_on = [module.eks, aws_eks_addon.metrics_server]
}
