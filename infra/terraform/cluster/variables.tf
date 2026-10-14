# 입력 변수 — snake_case + description 필수 (컨벤션 5-2)
# team_iam_users — 클러스터 관리자 IAM 사용자 이름 목록, 기본값 ["sesac-a1", "sesac-a2", "sesac-a3", "sesac-a4"] (팀원 4명). ARN 은 data.aws_caller_identity 로 조합 — 계정 ID 하드코딩 금지 · *.tfvars 는 gitignore 라 CI 가 못 읽으므로 기본값으로 둔다
