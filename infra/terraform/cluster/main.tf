# EKS 모듈(~> 20) — 1.35 · 퍼블릭 엔드포인트 · OIDC 공급자. apply 순서 5 (app 다음 — app output 을 읽는다. cicd/ 와는 상태 의존 없음)
# access_entries — 팀원 전원(IAM 사용자, variables.tf team_iam_users) + GitHub Actions 역할(이름 sesac-gojigi-github-actions 로 조회 — 있으면 추가, 없으면 생략) 모두 AmazonEKSClusterAdminPolicy(cluster 범위) 로 동일하게.
#   enable_cluster_creator_admin_permissions = false — 매일 08:00 클러스터를 만드는 주체가 Actions 역할이라 true 면 그 역할만 관리자가 된다. 생성자를 access_entries 에도 적으면 중복 오류
# 노드 그룹 2개 (3티어, 10/13 3차 · 10/14 사이징 조정):
#   app = t3.xlarge ×2 (4 vCPU · 16GiB · 파드 58/노드, AL2023, min 0 · max 3 · desired 2, 프라이빗 2a · 2c, gp3 40GiB 암호화, 라벨 tier=app)
#         — gateway ×2 · 업무 서비스 8 · Keycloak · 관측성 5 · ArgoCD 5 · 시스템 ≈ 35 파드 · requests 약 9.8Gi · 실사용 약 12~13Gi (할당 약 30Gi, 노드 1대로도 수용)
#         — 10/14 t3.large ×2 에서 조정: 실사용 여유 1~2Gi · 08:00 JVM 동시 기동 CPU 크레딧 · N-1 시연 불가. 약 $0.208/h × 2 → 6주 약 $245
#   db  = t3.medium ×1 (AL2023, min 0 · max 1 · desired 1, 프라이빗 2a 고정, gp3 20GiB 암호화, 라벨 tier=db + 테인트 tier=db:NoSchedule)
#         — MySQL · Redis 만 (toleration). EBS gp3 PVC 가 2a 에 묶이므로 서브넷은 private_subnets[0](2a) 하나. 약 $0.052/h → 6주 약 $31
#   Helm deployment.yaml 은 nodeSelector tier=app, deploy/k8s/db/*.yaml 은 nodeSelector tier=db + toleration
# VPC CNI 애드온에 enableNetworkPolicy=true (deploy/k8s/02-networkpolicy.yaml 이 DB 티어 3306 · 6379 를 tier=backend 파드만 허용)
# 애드온은 lbc.tf · ebs-csi-driver.tf · metrics-server.tf 뿐 (ESO 없음 — 시크릿은 secrets-sync 워크플로). IRSA 역할은 irsa.tf. 매일 08:00 apply · 22:00 destroy (infra-schedule.yml)
# 담당 구지훈 · 가이드라인 04장(main.tf 예시 코드) · 스펙 03-4

locals {
  private_subnets = data.terraform_remote_state.vpc.outputs.private_subnets # [2a, 2c]

  # 팀원 전원 + (있으면) Actions 역할 — 모두 같은 클러스터 관리자 권한
  cluster_admin_arns = merge(
    { for u in var.team_iam_users : u => "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${u}" },
    { for arn in data.aws_iam_roles.github_actions.arns : "github-actions" => arn },
  )
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true # 팀원 각자 PC · Actions 러너에서 kubectl (API 443)

  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = local.private_subnets

  # 매일 재생성 클러스터 — KMS 키(삭제 대기 7일+)와 제어 평면 로그 그룹을 만들지 않는다
  create_kms_key              = false
  cluster_encryption_config   = {}
  create_cloudwatch_log_group = false
  cluster_enabled_log_types   = []

  # 기본 애드온. vpc-cni 는 노드보다 먼저 + NetworkPolicy 활성화 (deploy/k8s/02-networkpolicy.yaml)
  cluster_addons = {
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
      })
    }
    kube-proxy = { most_recent = true }
    coredns    = { most_recent = true }
  }

  # EKS 관리형 metrics-server 는 10251 포트 — 모듈 기본 규칙(443 · 4443 · 6443 · 8443 · 9443 · 10250)에 없어
  # 제어 평면 → 파드 연결이 막히면 APIService 가 FailedDiscoveryCheck 로 kubectl top 불가
  node_security_group_additional_rules = {
    ingress_cluster_10251_metrics_server = {
      description                   = "Cluster API to metrics-server (EKS addon secure-port 10251)"
      protocol                      = "tcp"
      from_port                     = 10251
      to_port                       = 10251
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  # 파드가 IMDS 로 노드 IAM 역할(CNI · ECR 권한)을 빌리지 못하게 hop limit 1 — 모듈 기본값 2 는 IRSA 없는 파드(payment · gateway · admin · Keycloak)에도
  # 노드 권한을 준다(10/14 재현). aws-node(VPC CNI)는 hostNetwork 라 영향 없음, 파드는 IRSA 로만 AWS 권한
  eks_managed_node_group_defaults = {
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required" # IMDSv2 만
      http_put_response_hop_limit = 1
    }
  }

  eks_managed_node_groups = {
    # ── 백 티어: gateway · 업무 서비스 · Keycloak · 관측성 · ArgoCD
    app = {
      name            = "sesac-gojigi-app" # 이름 고정 — 기본값(app-{타임스탬프})은 매일 바뀌어 scripts/scale-nodes.sh 가 못 찾음
      use_name_prefix = false
      ami_type        = "AL2023_x86_64_STANDARD"
      instance_types  = ["t3.xlarge"] # 4 vCPU / 16GiB, 파드 58개 — 실사용 12~13Gi · 노드 1대로도 수용(N-1)
      capacity_type   = "ON_DEMAND"
      min_size        = 0 # scripts/scale-nodes.sh(수동 보조)로 0까지. 야간 절약은 22:00 destroy
      max_size        = 3 # 장애 · 복구 시연 때 3대
      desired_size    = 2
      subnet_ids      = local.private_subnets # 2a · 2c
      labels          = { tier = "app" }      # Helm Deployment nodeSelector

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 40 # JVM 이미지 9개 + Keycloak · 관측성 이미지 캐시
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }

    # ── DB 티어: MySQL · Redis 만. EBS gp3 PVC 가 2a 에 묶이므로 노드도 2a 고정
    db = {
      name            = "sesac-gojigi-db"
      use_name_prefix = false
      ami_type        = "AL2023_x86_64_STANDARD"
      instance_types  = ["t3.medium"] # 2 vCPU / 4GiB — MySQL 1Gi + Redis 128Mi + 시스템 ≈ 1.7Gi
      capacity_type   = "ON_DEMAND"
      min_size        = 0
      max_size        = 1
      desired_size    = 1
      subnet_ids      = [local.private_subnets[0]] # private-a (2a)
      labels          = { tier = "db" }
      taints = { # toleration 이 있는 MySQL · Redis 외에는 스케줄되지 않음
        db = { key = "tier", value = "db", effect = "NO_SCHEDULE" }
      }

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }
  }

  # 클러스터를 매일 만드는 주체는 Actions 역할 → 자동 관리자 등록을 끄고 전부 명시 (true + 중복 명시는 오류)
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false

  access_entries = {
    for name, arn in local.cluster_admin_arns : name => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}
