# 인프라 인수인계 — AWS IaC (구지훈 → 이경석 · 박지연 · 서비스 담당)

> 작성 2026-10-14 · 담당 구지훈 · 관련 PR [#1](https://github.com/sesac-final-1/gotgan-config/pull/1) · [#2](https://github.com/sesac-final-1/gotgan-config/pull/2) · [#3](https://github.com/sesac-final-1/gotgan-config/pull/3) · [#5](https://github.com/sesac-final-1/gotgan-config/pull/5)
> 설계 근거는 가이드라인 04 · 05 · 12 · 15장, 이벤트 계약은 [`events.md`](events.md), 시크릿 목록은 [`secrets.md`](secrets.md)

## 0. 요약

- **상시 자원은 전부 생성됨** — VPC · ECR · EIP · S3 · SNS/SQS · DynamoDB · SES · SSM (terraform plan "No changes")
- **클러스터(`cluster/`)는 코드 완료 · 실클러스터 검증 완료 · 현재 삭제 상태** — 매일 08:00 생성 · 22:00 삭제는 `infra-schedule` 워크플로 담당(10/26 부터 EventBridge Scheduler → Lambda 가 실행)
- **막혀 있는 것 하나**: GitHub Actions 역할(`cicd/`, 이경석)이 아직 없어 워크플로가 AWS에 로그인하지 못함 → 4페이즈(일일 스케줄 실검증)는 그 뒤

---

## 1. 경계 — 누가 무엇을 만들었고 맡는가

| 영역 | 구지훈 (완료) | 이경석 (CI/CD) | 박지연 (로깅 · 관측성) |
| --- | --- | --- | --- |
| Terraform | `global/s3` · `vpc` · `ecr` · `app` · `cluster`(EKS · 노드 그룹 · 애드온 · LBC · 서비스 IRSA 6개) | **`cicd/`** — GitHub OIDC 공급자 · Actions 역할 (작성 · 로컬 apply) | **`cluster/irsa_grafana.tf`** — grafana CloudWatch 읽기 IRSA |
| GitHub | — | `AWS_ROLE_ARN` 등록(config · backend), backend CI · ArgoCD · SonarCloud · gitleaks | — |
| k8s 매니페스트 | `deploy/k8s/00 · 01 · 02` · `db/`(MySQL · Redis · StorageClass · init-schemas) | `deploy/argocd/` · `deploy/helm/`(Deployment · Service 템플릿) · `deploy/k8s/keycloak/` | `deploy/observability/` 전체 |
| 워크플로 | `infra` · `infra-schedule` · `bootstrap` · `secrets-sync` (인프라 자동화 — bootstrap 안의 ArgoCD · 관측성 단계 **내용**은 각 담당 매니페스트를 그대로 적용) | `backend.yml` · `serverless.yml` · `security.yml` | — |
| 공유 파일에서 채운 줄 | `values.yaml`: `image.registry` · `roleArn` 6개 · gateway NLB 어노테이션 / `01-configmap.yaml`: AWS 자원 구획 | `values.yaml`의 나머지 (tag 줄은 backend CI만) | — |
| 서버리스 | 공유 자원(버킷 · 큐 · 테이블 · SSM). Lambda 코드: `order-notification` · `settlement-report` | 배포 파이프라인(`serverless.yml`) | Lambda 코드: `log-archive` |

> 경계 원칙: **AWS 자원과 그 이름 · ARN은 구지훈**, **배포 · 파이프라인은 이경석**, **수집 · 시각화는 박지연**. 서로의 파일은 PR로만 수정합니다(컨벤션 1-4).

---

## 2. 자원 목록

### 상시 (매일 삭제되지 않음)

| 폴더 | 자원 | 이름 · 값 |
| --- | --- | --- |
| `global/s3` | Terraform 상태 버킷 (버전 관리 · 삭제 방지) | `sesac-gojigi-tfstate-4380` — 이 폴더만 로컬 상태 |
| `vpc` | VPC 10.0.0.0/16 | `vpc-022347ef006692666` |
| | 퍼블릭 서브넷 [2a, 2c] | `subnet-023c11797072725df` · `subnet-0d52b05d6f680839c` |
| | 프라이빗 서브넷 [2a, 2c] | `subnet-0e6a2e34b63b63be9` · `subnet-0acb72a4bc47ecae4` |
| | NAT 게이트웨이 1개 (2a) | 공인 IP `52.79.161.22` (외부 IP 허용 목록이 필요할 때) |
| `ecr` | 저장소 9개 · 최근 10개 보관 | `694951014380.dkr.ecr.ap-northeast-2.amazonaws.com/sesac-gojigi-{gateway · user · store · product · order · settlement · payment · review · admin}` |
| `app` | NLB용 EIP [2a, 2c] | `3.34.245.213`(eip-0) · `13.125.139.205` / `eipalloc-00eaad35e9b548733` · `eipalloc-026aa7de15c62370c` |
| | Route 53 · ACM (`dns.tf`) | 호스팅 영역 `gotgan.click`(10/20 등록) · `api.gotgan.click` A → EIP 2개 · ACM 인증서(gateway NLB 443 TLS) |
| | S3 버킷 4개 | `sesac-gojigi-images-4380`(products/ · reviews/ · stores/ 공개 읽기) · `-seller-docs-4380` · `-reports-4380` · `-log-archive-4380`(90일 후 Glacier) |
| | SNS 토픽 3 · SQS 큐 9 + DLQ 9 | `sesac-gojigi-{store · order · settlement}-events` / `sesac-gojigi-{소비자}-{도메인}-events` (+`-dlq`) |
| | DynamoDB 2 | `sesac-gojigi-notifications` · `sesac-gojigi-settlement-reports` |
| | SES 발신 주소 (샌드박스) | `wlsgksvheh@gmail.com` (Verified) |
| | SSM 파라미터 8 | `/sesac-gojigi/dev/...` — `serverless.yml`이 읽음 |

### 매일 생성 · 삭제 (`cluster/`)

| 자원 | 내용 |
| --- | --- |
| EKS | `sesac-gojigi-eks-cluster` 1.35 · 퍼블릭 엔드포인트 · 인증 모드 API |
| 노드 그룹 | `sesac-gojigi-app` t3.xlarge ×2(2a · 2c, `tier=app`) · `sesac-gojigi-db` t3.medium ×1(2a, `tier=db` + 테인트 `tier=db:NoSchedule`) |
| 애드온 | vpc-cni(**NetworkPolicy 활성화**) · coredns · kube-proxy · aws-ebs-csi-driver · metrics-server (모두 EKS 관리형) |
| Helm | AWS Load Balancer Controller 3.5.0 (`kube-system`) |
| IRSA | `sesac-gojigi-{user · store · product · order · review · settlement}-irsa` · `-lbc-irsa` · `-ebs-csi-irsa` — 이름 고정이라 ARN 불변 |
| 접근 권한 | 팀원 전원(`sesac-a1` ~ `a4`) + Actions 역할(있으면 자동) → 모두 클러스터 관리자 |

---

## 3. 값 찾는 법

```bash
cd infra/terraform/<폴더> && terraform init && terraform output        # 폴더별 output 전체 (읽기만, 누구나 가능)
aws ssm get-parameters-by-path --path /sesac-gojigi/dev --recursive     # 서버리스용 파라미터
```

| 필요한 값 | 위치 |
| --- | --- |
| 서비스가 쓰는 토픽 ARN · 큐 URL · 버킷 | ConfigMap `app-config` (`deploy/k8s/01-configmap.yaml`) — 파드에 envFrom으로 자동 주입 |
| IRSA 역할 ARN | `values.yaml` 각 서비스 `serviceAccount.roleArn` |
| NLB 서브넷 · EIP | `values.yaml` gateway `service.annotations` |
| 서버리스 ARN · 이름 | SSM `/sesac-gojigi/dev/...` |

---

## 4. 접속 (SSH 없음)

```bash
aws configure                    # 본인 IAM 사용자(sesac-aN) 키, region ap-northeast-2
aws sts get-caller-identity      # 본인 확인
# 클러스터가 있을 때(08:30~22:00) — 매일 새로 생기므로 아침마다 1번
aws eks update-kubeconfig --name sesac-gojigi-eks-cluster --region ap-northeast-2 --alias gotgan
kubectl config use-context gotgan            # docker-desktop 과 헷갈리지 않게 이름을 gotgan 으로 고정
kubectl -n sesac-gojigi port-forward svc/keycloak 8180:8080   # Keycloak 콘솔
kubectl -n monitoring port-forward svc/grafana 3000:3000      # Grafana
```

- 노드는 프라이빗 서브넷 · 22번 포트 닫힘 — 노드에 들어갈 일이 없습니다
- 22:00 이후엔 클러스터가 없어서 `kubectl`이 연결되지 않는 것이 정상입니다. 컨텍스트를 `docker-desktop`으로 돌려 두세요

---

## 5. 하루 수명주기 · 운영

```
08:00  infra-schedule(apply) → terraform apply cluster/ (약 15분)
       └→ bootstrap → namespace · configmap · networkpolicy → secrets-sync → db(MySQL · Redis) → keycloak → 관측성 → ArgoCD → 서비스 9개
22:00  infra-schedule(destroy) → ArgoCD 앱 → LoadBalancer Service → PVC 삭제 → NLB 제거 대기 → terraform destroy cluster/
```

> 10/26 부터 시각은 EventBridge Scheduler(Asia/Seoul) → Lambda `sesac-gojigi-infra-dispatch` → workflow_dispatch 가 맞춥니다(신호 후 3~5초 안에 시작). 그 전 GitHub 예약은 1.5~4시간 늦었습니다. 08:00 시작이라 사용 가능은 약 08:30

- 수동 실행: Actions → `infra-schedule` → Run workflow → `apply` / `destroy`
- **destroy 전에 LoadBalancer Service · PVC를 먼저 지워야** 고아 NLB · EBS가 남지 않습니다(워크플로가 처리, 손으로 지울 때도 같은 순서)
- 노드 수 수동 조정(보조): `scripts/scale-nodes.sh up | down` — `sesac-gojigi-app`만 대상
- apply · destroy 권한: 워크플로(Actions 역할) 또는 구지훈. **다른 팀원은 plan까지**, 예외로 `cicd/`는 이경석

---

## 6. 이경석 (CI/CD) 연결점

**`cicd/` 작성 시 반드시 맞출 것** (cluster가 이 이름으로 역할을 찾습니다)

| 항목 | 값 |
| --- | --- |
| 역할 이름 | `sesac-gojigi-github-actions` (정확히) |
| output | `github_actions_role_arn` |
| backend | 버킷 `sesac-gojigi-tfstate-4380`, key `cicd/terraform.tfstate`, `use_lockfile = true` — `vpc/provider.tf` 복사 후 key만 변경 |
| OIDC `sub` | `repo:sesac-final-1/gotgan-config:ref:refs/heads/main` · `repo:sesac-final-1/gotgan-config:pull_request` · `repo:sesac-final-1/gotgan-backend:*` |
| 권한 | `cluster/` apply · destroy(EKS · EC2 · IAM 역할/정책 생성 · Helm) + ECR push(`ecr` output `repository_arns`) + 상태 버킷 읽기/쓰기(`arn:aws:s3:::sesac-gojigi-tfstate-4380`) |

- apply 후 `AWS_ROLE_ARN`을 **config · backend 두 저장소**에 ARN 형식으로 다시 등록 — 지금 PR마다 `plan (*)` 잡이 `Source Account ID is needed if the Role Name is provided` 로 실패하는 원인
- 역할이 생기면 다음 cluster apply 때 access entry가 **자동으로** 추가됩니다(`cluster` output `access_entry_principals`에 `github-actions` 표시)
- `values.yaml`에 이미 채운 것(건드리지 않아도 됨): 레지스트리 · `roleArn` 6개 · gateway NLB 어노테이션 3줄
  - **`aws-load-balancer-attributes: load_balancing.cross_zone.enabled=true`를 빼면 2c 쪽 EIP가 응답하지 않습니다**(10/14 검증)
- 남은 TODO(경석 님 영역): `bootstrap.yml`의 ArgoCD `stable` 매니페스트 버전 고정 · `security.yml` gitleaks · SonarCloud
- Keycloak 파드는 라벨 `tier: backend` · `nodeSelector tier=app`을 유지해야 NetworkPolicy가 MySQL 접근을 허용합니다

## 7. 박지연 (로깅 · 관측성) 연결점

- **grafana IRSA**는 `cluster/irsa_grafana.tf`로 작성 — 클러스터와 함께 매일 재생성됩니다. 같은 모듈 패턴 예시:

```hcl
module "grafana_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name        = "sesac-gojigi-grafana-irsa"
  role_policy_arns = { cw = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess" } # 필요하면 범위 축소한 정책으로
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["monitoring:grafana"] # grafana.yaml 의 ServiceAccount 이름과 맞출 것
    }
  }
}
```

- PR로 올리면 plan은 CI가, apply는 다음 08:00 스케줄(또는 구지훈)이 합니다
- Prometheus · Loki 볼륨: `storageClassName: ebs-sc` (gp3 · 암호화 · `WaitForFirstConsumer`) · 노드 `tier=app`
- `grafana-secret`(admin-password) · `alert-webhook-secret`(url)은 `secrets-sync`가 `monitoring` 네임스페이스에 만듭니다 — `grafana.yaml`에서 참조만 하면 됨
- bootstrap은 `kubectl apply -f deploy/observability/`(하위 폴더 미포함) — dashboards · alerting을 ConfigMap으로 바꾸면 `-R`로 바꿔야 합니다
- log-archive Lambda: 버킷 `sesac-gojigi-log-archive-4380`, SSM `/sesac-gojigi/dev/s3/log-archive-bucket`
- **파드는 IRSA 없이는 AWS 권한이 없습니다**(IMDS 차단) — CloudWatch를 읽는 컴포넌트는 반드시 IRSA로

## 8. 서비스 담당 연결점

| 서비스 | AWS 권한 (IRSA) | ConfigMap 변수 |
| --- | --- | --- |
| user | SQS 수신 | `USER_STORE_EVENTS_QUEUE_URL` · `USER_ORDER_EVENTS_QUEUE_URL` |
| store | SNS 발행 · S3 seller-docs Put/Get · S3 images/stores/ Put | `STORE_EVENTS_TOPIC_ARN` · `SELLER_DOCS_BUCKET` · `IMAGES_BUCKET` |
| product | SQS 수신 · S3 images/products/ Put | `PRODUCT_STORE_EVENTS_QUEUE_URL` · `IMAGES_BUCKET` |
| order | SNS 발행 | `ORDER_EVENTS_TOPIC_ARN` |
| review | SQS 수신 · S3 images/reviews/ Put | `REVIEW_ORDER_EVENTS_QUEUE_URL` · `IMAGES_BUCKET` |
| settlement | SQS 수신 · SNS 발행 · S3 reports Get | `SETTLEMENT_*_EVENTS_QUEUE_URL` · `SETTLEMENT_EVENTS_TOPIC_ARN` · `REPORTS_BUCKET` |
| gateway · payment · admin | 없음 | — |

- AWS SDK는 **키 없이** 사용 (IRSA가 자격 증명 주입, 리전 `AWS_REGION`). 권한 밖 호출은 `AccessDenied`
- 발행: 봉투 JSON만 publish (MessageAttributes 불필요 — 본문 `eventType`으로 구독 필터) / 소비: raw delivery, 3회 실패 시 `-dlq`
- 이미지: DB에는 key만 — 키에 폴더가 포함됨(`products/{storeId}/{UUID}.{확장자}` · `reviews/…` · `stores/…`). 표시 URL = `IMAGES_BASE_URL` + `/` + key (product.md 공통 표 · 10/21 박지연 답변 J3)
- 이벤트 · 구독자 변경은 [`events.md`](events.md)에 먼저 등록 → 구지훈이 `app/sns_sqs.tf` 구독 필터 반영

---

## 9. 설계 결정 · 알려진 함정 (실클러스터 검증에서 확인)

| 항목 | 내용 |
| --- | --- |
| IMDS hop limit 1 | 기본값(2)이면 IRSA 없는 파드도 노드 IAM 역할(CNI · ECR 권한)을 씀 → 1로 차단. 파드 AWS 권한은 **IRSA로만** |
| NLB cross-zone | 어노테이션이 없으면 파드 없는 AZ의 EIP는 무응답 |
| metrics-server 10251 | EKS 관리형 metrics-server 포트 — 노드 SG에 허용 규칙 추가돼 있음(지우면 `kubectl top` 불가) |
| metrics-server 버전 | EKS 1.35 기본 애드온 v0.9.0 이 protobuf `/openapi/v2` 를 503 으로 만들어 ArgoCD 동기화(`Unknown`) · LBC Helm 설치가 실패 → **`v0.8.1-eksbuild.21` 고정**(이슈 #11 · PR #12). LBC 의 `disable_openapi_validation = true` 는 같은 증상의 이전 우회책으로 안전장치로 유지 |
| gateway NLB 포트 | Helm Service 템플릿이 `port = targetPort = 8080` 이라 NLB 가 8080 으로 열림 → `vercel.json`(80번)과 불일치. gateway 만 NLB 80 → 파드 8080 으로 분리 필요 (Helm 담당 이경석, 10/15 확인) |
| 노드 그룹 이름 | `sesac-gojigi-app` · `-db` 고정 (기본값은 매일 바뀜) |
| KMS · 로그 그룹 | 매일 재생성이라 EKS KMS 키 · 제어 평면 로그를 만들지 않음 |
| SNS 필터 | 새 구독 · 필터는 퍼지는 데 수 분 걸림 / SQS purge는 최대 60초 — 그 사이 보낸 메시지도 지워짐 |
| SES | 샌드박스 — 수신자도 인증 필요(`app` 변수 `ses_recipient_emails`), Gmail 발신이라 스팸함 가능 |
| 비용 확인 | 교육 조직 연계 계정이라 Budgets · Cost Explorer 불가 → Tag Editor로 `Project=sesac-gojigi` 검색 |
| 로컬 Terraform | **1.16.5 고정**, 잠금 파일은 `terraform providers lock -platform=windows_amd64 -platform=linux_amd64` |

---

## 10. 남은 일 (구지훈)

| 작업 | 선행 조건 |
| --- | --- |
| 4페이즈 — `infra-schedule` apply/destroy 실행, bootstrap 전 과정(MySQL 스키마 8 · Redis AOF · NetworkPolicy 실동작 · NLB+EIP · 고아 자원 0) 확인 후 **크론 켜기** | 이경석 `cicd/` apply · `AWS_ROLE_ARN` |
| 2주차 말 걷는 뼈대(목업 서비스 1개: NLB → gateway → 응답 · 로그 · 자동 배포) | 4페이즈 · CI/CD · 로깅 연결 |
| SES 수신자(시연 계정) 추가 | 시연 계정 이메일 확정 |
| 서버리스 `order-notification` · `settlement-report` 구현 · 배포 | 4~5주차 |
