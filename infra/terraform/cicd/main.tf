# GitHub OIDC 공급자 · Actions 역할(ECR push · Serverless 배포 · SSM 읽기 · cluster/ apply · destroy) — 이경석 작성 · 구지훈 리뷰. apply 순서 4 (cluster 보다 먼저 — cluster 의 access_entries 가 Actions 역할을 이름으로 찾는다). output → GitHub Secret AWS_ROLE_ARN
# 신뢰 정책 조건 token.actions.githubusercontent.com:sub — 하나라도 빠지면 그 워크플로가 AssumeRole 에서 실패 (목록: variables.tf github_oidc_subjects)
#   repo:sesac-final-1@341724939/gotgan-config@1416543587:ref:refs/heads/main   (infra-schedule 스케줄 · bootstrap · secrets-sync · workflow_dispatch)
#   repo:sesac-final-1@341724939/gotgan-config@1416543587:pull_request          (infra.yml PR plan)
#   repo:sesac-final-1@341724939/gotgan-backend@1416543417:ref:refs/heads/main  (backend.yml ECR push · serverless.yml — 둘 다 main push 에서만 AWS 를 쓰므로 * 대신 main 으로 좁힘)
# 권한: infra-schedule 이 cluster/ 를 apply · destroy 한다 → EKS · EC2 · IAM(IRSA 역할 생성) · tfstate 버킷 읽기/쓰기까지 필요
# 로컬 apply 전용 폴더 (워크플로가 쓸 역할을 만드는 폴더라 워크플로로 apply 하지 않는다)
# 담당 구지훈 · 가이드라인 04장 · 스펙 03-4
# 권한 — AdministratorAccess (10/15 이경석 결정) repo:gotgan-config PR#7 참고

# GitHub Actions OIDC 공급자 — 계정에 URL 당 하나. AWS 가 GitHub 인증서를 직접 신뢰하므로 thumbprint 는 형식상 값
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# 신뢰 정책 — 이 OIDC 공급자가 발급한 토큰 중 aud = sts.amazonaws.com · sub 가 허용 목록에 있는 것만
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_oidc_subjects
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = var.github_actions_role_name
  description          = "GitHub Actions (gotgan-config, gotgan-backend) OIDC role"
  assume_role_policy   = data.aws_iam_policy_document.github_actions_trust.json
  max_session_duration = var.max_session_duration
}

resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}