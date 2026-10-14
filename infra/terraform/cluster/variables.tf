# 입력 변수 — snake_case + description 필수 (컨벤션 5-2)
# team_iam_users — 클러스터 관리자 IAM 사용자 이름 목록, 기본값 ["sesac-a1", "sesac-a2", "sesac-a3", "sesac-a4"] (팀원 4명). ARN 은 data.aws_caller_identity 로 조합 — 계정 ID 하드코딩 금지 · *.tfvars 는 gitignore 라 CI 가 못 읽으므로 기본값으로 둔다

variable "aws_region" {
  description = "AWS 리전 (서울)"
  type        = string
  default     = "ap-northeast-2"
}

variable "cluster_name" {
  description = "EKS 클러스터 이름 — GitHub Variable EKS_CLUSTER_NAME · vpc/ 서브넷 태그와 같은 값"
  type        = string
  default     = "sesac-gojigi-eks-cluster"
}

variable "cluster_version" {
  description = "EKS 쿠버네티스 버전"
  type        = string
  default     = "1.35"
}

variable "team_iam_users" {
  description = "클러스터 관리자(AmazonEKSClusterAdminPolicy)로 등록할 IAM 사용자 이름 — 팀원 4명. tfvars 는 gitignore 라 CI 가 못 읽으므로 기본값으로 둔다"
  type        = list(string)
  default     = ["sesac-a1", "sesac-a2", "sesac-a3", "sesac-a4"]
}

variable "github_actions_role_name" {
  description = "cicd/(이경석)가 만드는 GitHub Actions 역할 이름 — 있으면 access entry 에 추가, 없으면 생략"
  type        = string
  default     = "sesac-gojigi-github-actions"
}

variable "lbc_chart_version" {
  description = "AWS Load Balancer Controller Helm 차트 버전 — iam_policy.json 은 같은 버전의 공식 파일"
  type        = string
  default     = "3.5.0"
}
