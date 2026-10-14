# 다른 폴더 · 사람이 쓸 값 — terraform_remote_state 로 읽힌다

output "cluster_name" {
  description = "EKS 클러스터 이름 — aws eks update-kubeconfig --name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API 엔드포인트 (퍼블릭)"
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "클러스터 OIDC 공급자 ARN — IRSA 신뢰 정책 (매일 바뀜, irsa.tf · irsa_grafana.tf 가 같은 apply 안에서 사용)"
  value       = module.eks.oidc_provider_arn
}

output "node_security_group_id" {
  description = "노드 공용 보안 그룹 — 추가 인바운드 규칙이 필요할 때"
  value       = module.eks.node_security_group_id
}

output "access_entry_principals" {
  description = "클러스터 관리자로 등록된 주체 — Actions 역할이 빠져 있으면 cicd/ 미적용 상태"
  value       = keys(local.cluster_admin_arns)
}

output "kubeconfig_command" {
  description = "팀원 각자 실행할 kubeconfig 명령"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "node_group_names" {
  description = "관리형 노드 그룹 이름 (고정) — scripts/scale-nodes.sh"
  value       = { for k, ng in module.eks.eks_managed_node_groups : k => ng.node_group_id }
}
