// S5 실시간 연결 — 채팅 WebSocket(STOMP) 연결 · 구독 유지 + 일부는 1초에 1건 전송, 알림 SSE 연결 유지
// 통과: 연결 성공 > 99% · 메시지 왕복 p95 < 1s. 주로 보는 곳: chat · admin 메모리(연결당) · 스레드 · Redis
// 사용자당 연결 5개 제한(파드마다)이라 VU 는 계정을 돌려 쓴다(계정 COUNT 개). 연결은 1분 유지 후 다시 — 단계 동안 연결 수가 VU 수만큼 유지
//   k6 run -e LOADTEST_PASSWORD=... -e COUNT=200 loadtest/k6/s5-realtime.js     (채팅 50 → 200 → 500 · SSE 50 → 200)
import http from 'k6/http';
import { WebSocket } from 'k6/websockets';
import { check } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import exec from 'k6/execution';
import { BASE, login, authHeaders, post, stages, summaryTo } from './lib.js';

const COUNT = Number(__ENV.COUNT || 200);
const WS = BASE.replace(/^http/, 'ws') + '/ws/chat';
const ORIGIN = __ENV.ORIGIN || 'https://gotgan-ashy.vercel.app';   // chat 은 Origin 을 확인한다(allowed-origins)
const HOLD_MS = 60 * 1000;

const connected = new Rate('ws_connected');
const roundTrip = new Trend('chat_round_trip', true);
const sseOpen = new Rate('sse_held');
const frames = new Counter('ws_frames');

export const options = {
  scenarios: {
    chat: { executor: 'ramping-vus', stages: stages([50, 200, 500]), exec: 'chat', gracefulRampDown: '70s' },
    sse: { executor: 'ramping-vus', stages: stages([50, 200]), exec: 'sse', gracefulRampDown: '70s' },
  },
  thresholds: { ws_connected: ['rate>0.99'], chat_round_trip: ['p(95)<1000'], sse_held: ['rate>0.99'] },
};

const account = () => ((exec.vu.idInTest - 1) % COUNT) + 1;
const frame = (command, headers, body = '') => `${command}\n${Object.entries(headers).map(([k, v]) => `${k}:${v}`).join('\n')}\n\n${body}\0`;

let roomId = null;
let loggedIn = false;
const tokenOf = () => { if (!loggedIn) { login(account()); loggedIn = true; } return authHeaders().Authorization.slice(7); };   // 첫 반복에만 로그인, 이후 재사용 · 25분마다 refresh

export function chat() {
  const token = tokenOf();
  if (!roomId) {   // 계정마다 스토어 1 스토어 톡 방 하나(있으면 기존 방)
    const res = post('/api/chats/rooms', { type: 'STORE_INQUIRY', storeId: 1 }, 'POST /api/chats/rooms', authHeaders());
    roomId = res.json('data.roomId');
  }
  const sends = new Map();
  const ws = new WebSocket(WS, null, { headers: { Origin: ORIGIN } });
  let opened = false;
  ws.onopen = () => {
    ws.send(frame('CONNECT', { 'accept-version': '1.2', 'heart-beat': '10000,10000', Authorization: `Bearer ${token}` }));
  };
  ws.onmessage = (e) => {
    const data = String(e.data);
    frames.add(1);
    if (data.startsWith('CONNECTED')) {
      opened = true;
      connected.add(1);
      ws.send(frame('SUBSCRIBE', { id: 'room', destination: `/sub/rooms/${roomId}` }));
      const beat = setInterval(() => ws.send('\n'), 10000);   // 클라이언트 하트비트 — 없으면 서버가 약 30초 뒤 닫음
      const talker = Math.random() < 0.2;                      // 5명 중 1명은 1초에 1건 전송(연결마다 1초 5건 제한 안)
      const sender = talker ? setInterval(() => {
        const nonce = `${exec.vu.idInTest}-${Date.now()}`;
        sends.set(nonce, Date.now());
        ws.send(frame('SEND', { destination: `/pub/rooms/${roomId}`, 'content-type': 'application/json' }, JSON.stringify({ content: `부하 ${nonce}` })));
      }, 1000) : null;
      setTimeout(() => { clearInterval(beat); if (sender) clearInterval(sender); ws.close(); }, HOLD_MS);
    } else if (data.startsWith('MESSAGE')) {
      const m = data.match(/부하 (\d+-\d+)/);
      if (m && sends.has(m[1])) {
        roundTrip.add(Date.now() - sends.get(m[1]));
        sends.delete(m[1]);
      }
    } else if (data.startsWith('ERROR')) {
      check(data, { 'STOMP ERROR 없음': () => false });
    }
  };
  ws.onerror = () => { if (!opened) connected.add(0); };
}

// SSE — fetch-event-source 처럼 Authorization 헤더로 연결해 1분 유지. 끝까지 열려 있다가 타임아웃(오류 코드 1050)이면 "유지 성공"
export function sse() {
  const res = http.get(`${BASE}/api/notifications/stream`, {
    headers: { Authorization: `Bearer ${tokenOf()}`, Accept: 'text/event-stream', Origin: ORIGIN }, timeout: `${HOLD_MS / 1000}s`,
    tags: { name: 'GET /api/notifications/stream' }, responseCallback: http.expectedStatuses(200, 0),
  });
  sseOpen.add(res.error_code === 1050 || res.status === 200);
}

export const handleSummary = summaryTo('s5-realtime');
