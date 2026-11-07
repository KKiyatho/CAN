const { app } = require('@azure/functions');
const { DefaultAzureCredential } = require('@azure/identity');
const QUOTES = require('../../data/quotes.json');

const ENDPOINT = process.env.AOAI_ENDPOINT; // https://<name>.cognitiveservices.azure.com
const DEPLOYMENT = process.env.AOAI_DEPLOYMENT || 'gpt-4-1-nano';
const API_VERSION = '2024-10-21';
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

const credential = new DefaultAzureCredential();
const BY_ID = new Map(QUOTES.map((q) => [q.id, q]));

// 모델에는 후보 목록(id|저자|주제|앞부분)만 전달 → 모델은 id만 고른다. (명언 내용을 새로 만들지 않음)
const CANDIDATES = QUOTES.map((q) => `${q.id}|${q.authorKo}|${q.topics.join('/')}|${q.ko.slice(0, 40)}`).join('\n');

// 인스턴스 단위 간단 레이트 리미트 (IP당 분당 20회)
const hits = new Map();
function rateLimited(ip) {
  const now = Date.now();
  const arr = (hits.get(ip) || []).filter((t) => now - t < 60000);
  arr.push(now);
  hits.set(ip, arr);
  return arr.length > 20;
}

function corsHeaders(origin) {
  const ok = origin && ALLOWED_ORIGINS.includes(origin);
  return ok
    ? {
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        Vary: 'Origin',
      }
    : {};
}

const SYSTEM = `You pick the single best quotation for a user's emotion or situation from a fixed candidate list.
Candidate format: id|author|topics|beginning of quote.
Rules:
- Choose exactly ONE id from the list that best comforts, encourages or guides the user's situation. Never invent ids.
- Respond ONLY with JSON: {"id": string, "message": string}
- "message" is one short empathetic Korean sentence (max 60 chars) addressed to the user.

Candidates:
${CANDIDATES}`;

app.http('recommend', {
  methods: ['POST', 'OPTIONS'],
  authLevel: 'anonymous',
  route: 'recommend',
  handler: async (request, context) => {
    const origin = request.headers.get('origin');
    const cors = corsHeaders(origin);
    if (request.method === 'OPTIONS') return { status: 204, headers: cors };
    if (!origin || !cors['Access-Control-Allow-Origin']) {
      return { status: 403, jsonBody: { error: 'forbidden' } };
    }

    const ip = (request.headers.get('x-forwarded-for') || 'unknown').split(',')[0];
    if (rateLimited(ip)) {
      return { status: 429, headers: cors, jsonBody: { error: 'too_many_requests' } };
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return { status: 400, headers: cors, jsonBody: { error: 'bad_request' } };
    }
    const input = String(body?.input ?? '').trim().slice(0, 200);
    const lang = body?.lang === 'en' ? 'en' : 'ko';
    if (!input) return { status: 400, headers: cors, jsonBody: { error: 'empty_input' } };

    try {
      const token = await credential.getToken('https://cognitiveservices.azure.com/.default');
      const url = `${ENDPOINT}/openai/deployments/${DEPLOYMENT}/chat/completions?api-version=${API_VERSION}`;
      for (let attempt = 0; attempt < 2; attempt++) {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token.token}`,
        },
        body: JSON.stringify({
          messages: [
            { role: 'system', content: SYSTEM },
            { role: 'user', content: `Emotion/situation: ${input}` },
          ],
          temperature: 0.8,
          max_tokens: 120,
          response_format: { type: 'json_object' },
        }),
      });
      if (!res.ok) {
        context.error('AOAI error', res.status, await res.text());
        return { status: 502, headers: cors, jsonBody: { error: 'upstream' } };
      }
      const data = await res.json();
      const parsed = JSON.parse(data.choices[0].message.content);
      const idMatch = String(parsed.id ?? '').match(/q\d{4}/);
      const q = idMatch ? BY_ID.get(idMatch[0]) : null;
      if (!q) {
        context.error('invalid id from model', data.choices[0].message.content);
        continue;
      }
      return {
        status: 200,
        headers: cors,
        jsonBody: {
          id: q.id,
          content: lang === 'en' ? q.en : q.ko,
          author: lang === 'en' ? q.authorEn : q.authorKo,
          occupation: q.occupation,
          source: q.source,
          message: lang === 'en' ? null : String(parsed.message || ''),
          language: lang,
        },
      };
      }
      return { status: 502, headers: cors, jsonBody: { error: 'invalid_response' } };
    } catch (e) {
      context.error('recommend failed', e);
      return { status: 500, headers: cors, jsonBody: { error: 'server_error' } };
    }
  },
});

