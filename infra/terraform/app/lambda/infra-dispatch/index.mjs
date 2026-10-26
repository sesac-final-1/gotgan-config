// infra-dispatch — EventBridge Scheduler(서울 시각 정각)가 부르면 GitHub infra-schedule 워크플로를 workflow_dispatch 로 실행한다. 담당 구지훈
// terraform(약 27분)은 Lambda 제한(15분)을 넘으므로 여기서는 "실행 신호"만 보낸다 — 실제 apply · destroy 는 지금처럼 GitHub 러너가 한다.
// 토큰은 SSM SecureString(AWS 관리형 키 aws/ssm)에서 읽는다 — 값은 사람이 CLI 로 직접 넣고 Terraform 상태 · 코드에는 없다.
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm'; // Node.js 22 런타임 내장 SDK — 번들 불필요

const ssm = new SSMClient({});
const ACTIONS = new Set(['apply', 'destroy']);

export const handler = async (event) => {
  const action = event?.action;
  if (!ACTIONS.has(action)) throw new Error(`알 수 없는 action: ${action}`);

  const { Parameter } = await ssm.send(new GetParameterCommand({ Name: process.env.TOKEN_PARAMETER, WithDecryption: true }));
  const res = await fetch(`https://api.github.com/repos/${process.env.GITHUB_REPO}/actions/workflows/${process.env.WORKFLOW_FILE}/dispatches`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${Parameter.Value}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'sesac-gojigi-infra-dispatch',
    },
    body: JSON.stringify({ ref: 'main', inputs: { action } }),
  });
  // 성공은 204. 실패하면 예외 → 비동기 호출 재시도(Lambda 기본 2회) · 로그에 남는다 (토큰 값은 남기지 않음)
  if (res.status !== 204) throw new Error(`GitHub dispatch 실패 ${res.status}: ${(await res.text()).slice(0, 300)}`);
  console.log(`infra-schedule ${action} 실행 신호 보냄`);
  return { action, status: res.status };
};
