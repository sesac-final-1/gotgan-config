# 입력 변수 — snake_case + description 필수 (컨벤션 5-2)

variable "aws_region" {
  description = "AWS 리전 (서울)"
  type        = string
  default     = "ap-northeast-2"
}

variable "cluster_name" {
  description = "EKS 클러스터 이름 — 서브넷 태그 kubernetes.io/cluster/{이름} 에 사용 (GitHub Variable EKS_CLUSTER_NAME 과 같은 값)"
  type        = string
  default     = "sesac-gojigi-eks-cluster"
}
