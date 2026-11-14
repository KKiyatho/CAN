// 실존 인물의 명언 시드 생성 스크립트 (운영 데이터 갱신용 수동 도구)
// 사용: $env:AOAI_ENDPOINT='https://<resource>.cognitiveservices.azure.com'; $env:AOAI_KEY=...; node scripts/generate-seed.js
// 생성된 문구는 사람이 출처를 검수한 뒤 반영해야 한다.
const fs = require('fs');
const path = require('path');

const ENDPOINT = process.env.AOAI_ENDPOINT;
const DEPLOYMENT = process.env.AOAI_DEPLOYMENT || 'gpt-4-1-mini';
const KEY = process.env.AOAI_KEY;
if (!ENDPOINT || !KEY) throw new Error('AOAI_ENDPOINT, AOAI_KEY 환경 변수가 필요합니다.');

const OCCUPATIONS = ['철학자', '기업가', '작가', '과학자', '예술가', '운동선수', '정치가', '종교인'];
const TOPIC_TAGS = ['불안', '지침', '면접', '관계', '철학', '성공', '독서', '지혜', '창의력', '도전', '용기', '믿음', '사랑', '행복', '자기계발', '삶'];
const TOPIC_GROUPS = ['사랑', '행복', '자기계발', '삶', '불안', '지침', '도전과 면접', '관계', '용기'];

const OCC_EN = {
  철학자: 'philosophers', 기업가: 'entrepreneurs and business leaders', 작가: 'writers, poets and novelists',
  과학자: 'scientists and inventors', 예술가: 'artists, musicians, designers and filmmakers',
  운동선수: 'professional athletes and coaches', 정치가: 'statesmen, politicians and activists',
  종교인: 'religious leaders and spiritual teachers',
};

async function ask(prompt) {
  const url = `${ENDPOINT}/openai/deployments/${DEPLOYMENT}/chat/completions?api-version=2024-10-21`;
  for (let attempt = 0; attempt < 4; attempt++) {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'api-key': KEY },
      body: JSON.stringify({
        messages: [
          {
            role: 'system',
            content:
              'You are a meticulous quotation researcher. Output only quotations that are widely documented in published books, speeches, interviews or letters and reliably attributed to a real, famous person. Exclude apocryphal, disputed or commonly misattributed quotes. Prefer skipping over guessing. Respond only with JSON.',
          },
          { role: 'user', content: prompt },
        ],
        temperature: 0.7,
        max_tokens: 6000,
        response_format: { type: 'json_object' },
      }),
    });
    if (res.status === 429) {
      await new Promise((r) => setTimeout(r, 5000 * (attempt + 1)));
      continue;
    }
    if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
    const data = await res.json();
    return JSON.parse(data.choices[0].message.content);
  }
  throw new Error('retry exhausted');
}

const FORMAT = `Return JSON: {"quotes":[{"en":"original or standard English wording","ko":"faithful natural Korean translation","authorEn":"full name","authorKo":"Korean name as commonly written","occupation":"one of ${OCCUPATIONS.join('|')}|기타","topics":["1-3 items from: ${TOPIC_TAGS.join(', ')}"],"source":"book/speech if known else null","confidence":1-5}]}
confidence 5 = certain attribution; only include 4 or 5.`;

const norm = (s) => s.toLowerCase().replace(/[^a-z0-9가-힣]+/g, ' ').trim();

async function main() {
  const ONLY = (process.env.ONLY || '').split(',').filter(Boolean);
  const appPath = path.join(__dirname, '..', '..', 'can_app', 'assets', 'quotes_curated.json');
  const out = ONLY.length ? JSON.parse(fs.readFileSync(appPath, 'utf8')) : [];
  const seen = new Set(out.map((q) => norm(q.en)));
  const authorCount = new Map();
  for (const q of out) authorCount.set(q.authorEn, (authorCount.get(q.authorEn) || 0) + 1);

  async function run(label, buildPrompt, rounds) {
    for (let r = 0; r < rounds; r++) {
      const used = [...authorCount.entries()].filter(([, c]) => c >= 2).map(([a]) => a).slice(0, 150);
      const prompt = `${buildPrompt(r)}\nAuthors already used twice or more (avoid them): ${used.join(', ') || 'none'}.\n${FORMAT}`;
      let json;
      try {
        json = await ask(prompt);
      } catch (e) {
        console.error(label, 'failed', e.message);
        continue;
      }
      let added = 0;
      for (const q of json.quotes || []) {
        if (!q.en || !q.ko || !q.authorEn || !q.authorKo) continue;
        if ((q.confidence ?? 0) < 4) continue;
        if (/unknown|anonymous|미상|작자/i.test(q.authorEn + q.authorKo)) continue;
        const key = norm(q.en);
        if (seen.has(key)) continue;
        if ((authorCount.get(q.authorEn) || 0) >= 4) continue;
        seen.add(key);
        authorCount.set(q.authorEn, (authorCount.get(q.authorEn) || 0) + 1);
        const topics = (q.topics || []).filter((t) => TOPIC_TAGS.includes(t));
        const occupation = OCCUPATIONS.includes(q.occupation) ? q.occupation : null;
        out.push({
          en: q.en.trim(), ko: q.ko.trim(), authorEn: q.authorEn.trim(), authorKo: q.authorKo.trim(),
          occupation, topics, source: q.source || null,
        });
        added++;
      }
      console.log(`${label} round ${r + 1}: +${added} (total ${out.length})`);
    }
  }

  for (const occ of OCCUPATIONS.filter((o) => !ONLY.length || ONLY.includes(o))) {
    await run(occ, (r) =>
      `List 15 famous, well-documented quotations by real ${OCC_EN[occ]} (all "occupation" must be "${occ}"). Use at least 10 different people, varied themes, round ${r + 1} should emphasize different people than earlier rounds. Escape any double quotes inside strings.`, ONLY.length ? 6 : 3);
  }
  for (const g of TOPIC_GROUPS.filter((g) => !ONLY.length || ONLY.includes(g))) {
    await run(g, (r) =>
      `List 25 famous, well-documented quotations on the theme "${g}" by real famous people of varied professions and eras (round ${r + 1}; choose different people than earlier rounds). Set topics to include the relevant tag(s).`, 2);
  }

  // 점수 낮은/짧은 것 제거 후 id 부여
  const final = out
    .filter((q) => q.en.length >= 20 && q.ko.length >= 8)
    .map(({ id, ...q }, i) => ({ id: `q${String(i + 1).padStart(4, '0')}`, ...q }));

  const apiPath = path.join(__dirname, '..', 'data', 'quotes.json');
  fs.mkdirSync(path.dirname(apiPath), { recursive: true });
  fs.writeFileSync(appPath, JSON.stringify(final, null, 1), 'utf8');
  fs.writeFileSync(apiPath, JSON.stringify(final), 'utf8');
  console.log('saved', final.length);
}

main();
