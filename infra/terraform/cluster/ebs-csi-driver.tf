# EBS CSI 애드온 + IRSA 역할 sesac-gojigi-ebs-csi-irsa (MySQL · Redis · Prometheus · Loki 볼륨)

# IRSA — kube-system/ebs-csi-controller-sa 가 EBS 볼륨을 만들고 붙인다. 이름 고정 → ARN 불변
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "sesac-gojigi-ebs-csi-irsa"
  role_policy_arns = {
    ebs = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" # AWS 관리형 — 드라이버 버전에 맞춰 AWS 가 갱신
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

# 노드 그룹이 뜬 뒤 설치 (module.eks 완료 = 노드 그룹까지). node DaemonSet 은 모든 테인트를 허용 → db 노드에도 뜬다
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = module.ebs_csi_irsa.iam_role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}
