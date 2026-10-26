# infra/terraform (담당 구지훈)

폴더 1개 = `terraform apply` 1번 = 상태 파일 1개. apply 순서: `global/s3` → `vpc` → `ecr` → `app` → `cluster`. 의존은 `cluster` → 상시 폴더 한 방향뿐 — 상시 폴더는 매일 사라지는 `cluster` 를 읽지 않는다. `cicd/` 는 다른 폴더와 상태 의존이 없어 `global/s3` 이후 언제든 (이경석 작성 · apply — `cluster` 는 Actions 역할을 이름 `sesac-gojigi-github-actions` 로 찾고, 없으면 건너뛴다).

| 폴더 | 자원 | 수명 |
|---|---|---|
| `global/s3` | tfstate 버킷 (잠금은 S3 자체 `use_lockfile` — DynamoDB 테이블 없음) | 상시 |
| `vpc` | VPC · 서브넷 · NAT · IGW | 상시 |
| `ecr` | 서비스별 ECR 저장소 | 상시 |
| `cicd` | GitHub OIDC 공급자 · Actions 역할 (**이경석** 작성 · apply) | 상시 |
| `app` | S3 · SNS/SQS · DynamoDB · SES · SSM · EIP · 클러스터 일일 스케줄러(EventBridge Scheduler · Lambda infra-dispatch) | 상시 |
| `cluster` | EKS · 노드 그룹 · access entries(팀원 전원 + Actions 역할 — 있으면) · 서비스 IRSA(`irsa.tf`, grafana 는 박지연 `irsa_grafana.tf`) · LBC · EBS CSI · metrics-server | **매일 08:00 apply · 22:00 destroy** (`infra-schedule.yml` — `app/scheduler.tf` 의 EventBridge Scheduler → Lambda 가 실행) |

- apply/destroy 는 스케줄 워크플로(OIDC 역할 `AWS_ROLE_ARN`) 또는 구지훈. 예외: `cicd/` 는 이경석이 로컬 apply (워크플로가 쓸 역할을 만드는 폴더). 다른 사람은 `terraform plan` 까지 (컨벤션 5-2). PR 에서는 `infra.yml` 이 fmt · validate · plan 을 돌린다
- 시크릿은 GitHub Secrets 단일 소스 — Secrets Manager · KMS · ESO 없음. 클러스터 Secret 은 `secrets-sync` 워크플로가 만든다 (`docs/secrets.md`). **예외 1건**: 스케줄러 Lambda 의 GitHub 토큰은 SSM SecureString(AWS 관리형 키) `/sesac-gojigi/dev/github/infra-dispatch-token` — Terraform 이 값을 만들지 않고 구지훈이 CLI 로 등록 (`docs/secrets.md` 7절)
- Terraform 은 팀 · CI 모두 **1.16.5** (`required_version = "~> 1.16.0"`, 워크플로 `terraform_version: '1.16.5'`)
- 커밋 전 `terraform fmt -recursive` · `terraform validate`. `.terraform.lock.hcl` 커밋, `*.tfstate` · `.terraform/` 커밋 금지
- `.terraform.lock.hcl` 은 폴더의 `provider.tf` 를 쓰고 처음 `init` 한 뒤(그리고 provider 버전을 바꿀 때마다) `terraform providers lock -platform=windows_amd64 -platform=linux_amd64` 로 두 플랫폼 해시를 채워 커밋 — Windows · CI(Linux) 가 같은 잠금 파일을 쓴다
- 모든 자원 태그 `Project=sesac-gojigi`. AWS Budgets · Cost Explorer 는 쓰지 않음 — 교육 조직의 연계 계정이라 관리(payer) 계정에서만 열린다 (CLI · 콘솔 모두 AccessDenied)
- 삭제 순서(`infra-schedule.yml` destroy 잡이 수행): ArgoCD 앱 · Service(LoadBalancer) · PVC 먼저 → NLB 제거 대기 → cluster destroy. EIP 는 `app/` 소유라 남는다 → 다음 날 NLB 어노테이션으로 다시 붙어 `api.gotgan.click` DNS 변경 없음
- 각 `*.tf` 의 헤더 주석에 그 파일이 만들 자원을 적어 두었다 (가이드라인 04장 · 15장 8절)
