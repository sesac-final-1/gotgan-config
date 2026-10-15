# metrics-server — EKS 관리형 애드온 (kubectl top · 자원 확인). Helm 차트 아님

# EKS 관리형 애드온 — Helm 차트 대신 써서 버전 · 업그레이드를 EKS 에 맡기고, 클러스터와 함께 삭제
resource "aws_eks_addon" "metrics_server" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "metrics-server"
  addon_version               = "v0.8.1-eksbuild.21"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}
