'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createRecommendHandler, parseModelOutput } = require('../src/lib/recommend-core');

const ORIGIN = 'https://app.example';
const ENV = {
  AOAI_ENDPOINT: 'https://aoai.example',
  SUPABASE_URL: 'https://project.supabase.example',
  SUPABASE_PUBLISHABLE_KEY: 'publishable',
  ALLOWED_ORIGINS: ORIGIN,
  RATE_LIMIT_USER_PER_MINUTE: '3',
};

const KO_MODEL = {
  message: '충분히 잘하고 있어요.',
  quote: { content: '천 리 길도 한 걸음부터', author: '노자', source: '도덕경' },
  similar: [
    { content: '포기하지 않는 한 실패는 없다', author: '에디슨', source: null },
    { content: '오늘 할 수 있는 일을 내일로 미루지 마라', author: '프랭클린', source: null },
    { content: '시작이 반이다', author: '아리스토텔레스', source: null },
    { content: '중요한 것은 멈추지 않는 것이다', author: '공자', source: null },
    { content: '다섯 번째는 잘려야 한다', author: '추가 인물', source: null },
  ],
};

function request({ method = 'POST', headers = {}, body = { input: '면접이 떨려요', lang: 'ko' } } = {}) {
  const lower = Object.fromEntries(Object.entries(headers).map(([k, v]) => [k.toLowerCase(), v]));
  return {
    method,
    headers: { get: (name) => lower[name.toLowerCase()] ?? null },
    text: async () => (typeof body === 'string' ? body : JSON.stringify(body)),
  };
}

const context = { error() {}, warn() {} };
const authed = { authorization: 'Bearer token-1', 'x-forwarded-for': '1.1.1.1' };

function harness({ model = KO_MODEL, user = { id: 'u1', is_anonymous: false }, completionStatus = 200 } = {}) {
  const calls = { auth: 0, completion: 0 };
  const fetchImpl = async (url) => {
    if (url.includes('/auth/v1/user')) {
      calls.auth++;
      if (!user) return { ok: false, status: 401, json: async () => ({}) };
      return { ok: true, status: 200, json: async () => user };
    }
    calls.completion++;
    if (completionStatus !== 200) return { ok: false, status: completionStatus };
    return {
      ok: true,
      status: 200,
      json: async () => ({ choices: [{ message: { content: JSON.stringify(model) } }] }),
    };
  };
  const handler = createRecommendHandler({
    env: ENV,
    fetchImpl,
    getToken: async () => 'aoai-token',
  });
  return { handler, calls };
}

test('허용되지 않은 Origin은 403', async () => {
  const { handler } = harness();
  const res = await handler(request({ headers: { ...authed, origin: 'https://evil.example' } }), context);
  assert.equal(res.status, 403);
});

test('Origin이 없는 네이티브 요청도 인증되면 처리된다', async () => {
  const { handler } = harness();
  const res = await handler(request({ headers: authed }), context);
  assert.equal(res.status, 200);
  assert.equal(res.jsonBody.similar.length, 4);
});

test('허용된 Origin의 브라우저 요청에는 CORS 헤더가 붙는다', async () => {
  const { handler } = harness();
  const res = await handler(request({ headers: { ...authed, origin: ORIGIN } }), context);
  assert.equal(res.status, 200);
  assert.equal(res.headers['Access-Control-Allow-Origin'], ORIGIN);
});

test('프리플라이트는 인증 없이 204', async () => {
  const { handler, calls } = harness();
  const res = await handler(request({ method: 'OPTIONS', headers: { origin: ORIGIN } }), context);
  assert.equal(res.status, 204);
  assert.equal(calls.auth, 0);
});

test('Authorization 헤더가 없으면 401', async () => {
  const { handler } = harness();
  const res = await handler(request({ headers: { 'x-forwarded-for': '2.2.2.2' } }), context);
  assert.equal(res.status, 401);
});

test('유효하지 않은 토큰은 401이고 모델을 호출하지 않는다', async () => {
  const { handler, calls } = harness({ user: null });
  const res = await handler(request({ headers: authed }), context);
  assert.equal(res.status, 401);
  assert.equal(calls.completion, 0);
});

test('같은 토큰의 검증 결과는 짧게 캐시된다', async () => {
  const { handler, calls } = harness();
  await handler(request({ headers: authed }), context);
  await handler(request({ headers: authed }), context);
  assert.equal(calls.auth, 1);
});

test('사용자별 분당 한도를 넘으면 429', async () => {
  const { handler } = harness();
  const statuses = [];
  for (let i = 0; i < 5; i++) {
    statuses.push((await handler(request({ headers: authed }), context)).status);
  }
  assert.deepEqual(statuses, [200, 200, 200, 429, 429]);
});

test('잘못된 JSON과 빈 입력은 400', async () => {
  const { handler } = harness();
  assert.equal((await handler(request({ headers: authed, body: '{nope' }), context)).status, 400);
  const empty = await handler(request({ headers: authed, body: { input: '   ' } }), context);
  assert.equal(empty.status, 400);
  assert.equal(empty.jsonBody.error, 'empty_input');
});

test('너무 큰 본문은 413', async () => {
  const { handler } = harness();
  const res = await handler(request({ headers: authed, body: { input: 'a'.repeat(5000) } }), context);
  assert.equal(res.status, 413);
});

test('모델 서비스 오류는 502', async () => {
  const { handler } = harness({ completionStatus: 500 });
  const res = await handler(request({ headers: authed }), context);
  assert.equal(res.status, 502);
});

test('설정이 없으면 503', async () => {
  const handler = createRecommendHandler({ env: {}, fetchImpl: async () => {}, getToken: async () => '' });
  const res = await handler(request({ headers: authed }), context);
  assert.equal(res.status, 503);
});

test('기준에 못 미치는 모델 응답은 재시도 후 502', async () => {
  const { handler, calls } = harness({ model: { ...KO_MODEL, similar: [] } });
  const res = await handler(request({ headers: authed }), context);
  assert.equal(res.status, 502);
  assert.equal(calls.completion, 2);
});

test('parseModelOutput: 중복·같은 저자·언어 불일치·미상 저자를 제거한다', () => {
  const result = parseModelOutput(
    JSON.stringify({
      message: '힘내세요',
      quote: { content: '천 리 길도 한 걸음부터', author: '노자' },
      similar: [
        { content: '천 리 길도 한 걸음부터!', author: '다른 사람' },
        { content: '시작이 반이다', author: '노자' },
        { content: 'English only text', author: 'Someone' },
        { content: '작자 미상의 말', author: '작자 미상' },
        { content: '시작이 반이다', author: '아리스토텔레스' },
        { content: '꾸준함이 재능을 이긴다', author: '공자' },
      ],
    }),
    'ko',
  );
  assert.deepEqual(
    result.similar.map((q) => q.author),
    ['아리스토텔레스', '공자'],
  );
});

test('parseModelOutput: 길이를 넘는 인용은 자르지 않고 거부한다', () => {
  const result = parseModelOutput(
    JSON.stringify({ quote: { content: '가'.repeat(301), author: '노자' }, similar: [] }),
    'ko',
  );
  assert.equal(result, null);
});
