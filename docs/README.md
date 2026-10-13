# docs

| 경로 | 내용 | 언제 |
|---|---|---|
| `adr/` | 결정 기록 (Architecture Decision Record) — 무엇을 · 왜 · 대안. 템플릿 `adr/_template.md` | 회의 후 |
| `events.md` | 이벤트 목록 · 봉투 형식 · payload 필드 | 이벤트 추가 시 (구현 전에 먼저 등록) |
| `secrets.md` | GitHub Secrets · Variables 목록 · 용도 · 생성 방법 (**값 없음** — 값은 노션). `secrets-sync` 워크플로가 만드는 K8s Secret 이름 · 키의 기준 | 시크릿 추가 · 변경 시 |
| `CONVENTION.md` | 인프라 네이밍 · 로그/관측성 컨벤션 발췌본 — 문서 사이트 `project-convention.md` 에서 **자동 생성** (직접 고치지 않는다) | 컨벤션 개정 시 재생성 |

API 명세(OpenAPI · error-codes)는 `gotgan-backend/docs/api/`, 프론트 컨벤션은 `gotgan-frontend/docs/CONVENTION.md`.
설계 문서 전체는 문서 사이트 https://gotganguide.vercel.app/ (가이드라인 · 스펙 · 컨벤션).
