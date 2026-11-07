const { app } = require('@azure/functions');
const { DefaultAzureCredential } = require('@azure/identity');

const ENDPOINT = process.env.AOAI_ENDPOINT; // https://<name>.cognitiveservices.azure.com
const DEPLOYMENT = process.env.AOAI_DEPLOYMENT || 'gpt-4-1-nano';
const API_VERSION = '2024-10-21';
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

const credential = new DefaultAzureCredential();

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

function systemPrompt(lang) {
  const language = lang === 'en' ? 'English' : 'Korean';
  return `You are a compassionate quote curator. The user describes their situation or feelings.
Find real, well-documented quotations by real historical or contemporary people that would help them most.
Rules:
- "quote": the single most helpful quotation for this exact situation.
- "similar": exactly 4 other quotations with a similar theme or comforting angle (different authors, no duplicates of "quote").
- Only use quotations that are widely and reliably attributed to the named author. If unsure of the attribution or wording, choose a different quotation. Never invent quotes or authors.
- Write each quotation text in ${language} (translate faithfully if the original is in another language). Keep each under 200 characters.
- "author" is the real person's name in ${language}. "source" is the book/speech/work if known, otherwise null.
- "message": one short empathetic sentence in ${language} (max 60 chars) addressed to the user.
- Respond ONLY with JSON: {"message": string, "quote": {"content": string, "author": string, "source": string|null}, "similar": [{"content": string, "author": string, "source": string|null}]}`;
}

function cleanQuote(q) {
  const content = String(q?.content ?? '').trim().slice(0, 300);
  const author = String(q?.author ?? '').trim().slice(0, 80);
  if (!content || !author) return null;
  const source = q?.source ? String(q.source).trim().slice(0, 120) : null;
  return { content, author, source };
}

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
            { role: 'system', content: systemPrompt(lang) },
            { role: 'user', content: `Situation: ${input}` },
          ],
          temperature: 0.7,
          max_tokens: 1200,
          response_format: { type: 'json_object' },
        }),
      });
      if (!res.ok) {
        context.error('AOAI error', res.status, await res.text());
        return { status: 502, headers: cors, jsonBody: { error: 'upstream' } };
      }
      const data = await res.json();
      const parsed = JSON.parse(data.choices[0].message.content);
      const main = cleanQuote(parsed.quote);
      if (!main) {
        context.error('invalid quote from model', data.choices[0].message.content);
        continue;
      }
      const similar = (Array.isArray(parsed.similar) ? parsed.similar : [])
        .map(cleanQuote)
        .filter((q) => q && q.content !== main.content)
        .slice(0, 4);
      return {
        status: 200,
        headers: cors,
        jsonBody: {
          message: String(parsed.message || '').trim().slice(0, 120),
          quote: main,
          similar,
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

