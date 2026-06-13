/**
 * seed_all.js — quotes.json 전체 Firestore 배치 삽입 (무료 Spark 플랜 대응)
 *
 * ⚠️  Firestore 무료 플랜: 하루 20,000건 쓰기 한도
 *     36,937개 전체 = 2일 분할 실행 필요
 *
 * [1일차] node seed_all.js --skip 0   --limit 18000
 * [2일차] node seed_all.js --skip 18000
 *
 * 기타 옵션:
 *   --min-pop 0.005   인기도 0.005 이상만 (~5,000개, 하루에 완료)
 *   --limit 1000      처음 1000개만 테스트
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const path = require('path');

const serviceAccount = require('./serviceAccountKey.json');
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

// ── CLI 인수 파싱 ─────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const getArg = (flag) => {
  const i = args.indexOf(flag);
  return i !== -1 ? parseFloat(args[i + 1]) : null;
};
const LIMIT   = getArg('--limit')   ?? Infinity;
const MIN_POP = getArg('--min-pop') ?? 0;
const SKIP    = getArg('--skip')    ?? 0;

// ── 영어 태그/카테고리 → 한국어 태그 매핑 ────────────────────────────────────
const TAG_MAP = {
  // 카테고리 (Category 필드)
  life: '삶', love: '사랑', friendship: '우정', happiness: '행복',
  success: '성공', wisdom: '지혜', hope: '희망', humor: '유머',
  inspiration: '도전', motivational: '도전', motivation: '도전',
  faith: '믿음', philosophy: '철학', truth: '진실',
  education: '배움', knowledge: '배움', books: '독서',
  poetry: '예술', arts: '예술', science: '지혜', death: '삶',
  religion: '믿음', romance: '사랑', funny: '유머',
  courage: '용기', change: '변화', leadership: '성공',
  music: '음악', family: '관계', relationships: '관계', relationship: '관계',
  // 세부 태그 (Tags 배열)
  smile: '행복', joy: '행복', optimism: '긍정', optimistic: '긍정',
  dream: '꿈', dreams: '꿈', learning: '배움', reading: '독서',
  fear: '용기', freedom: '자유', kindness: '관계',
  beauty: '예술', peace: '명상', gratitude: '행복',
  failure: '도전', forgiveness: '용서', identity: '개성',
  individuality: '개성', growth: '자기계발', 'self-help': '자기계발',
  creativity: '창의력', imagination: '창의력', nature: '자연',
  time: '자기계발', strength: '용기', perseverance: '도전',
  patience: '자기계발', mindfulness: '명상', simplicity: '삶',
  character: '지혜', integrity: '진실', honesty: '진실',
  compassion: '관계', empathy: '관계', loss: '삶', age: '삶',
  youth: '삶', future: '희망', past: '삶', present: '삶',
  god: '믿음', spirituality: '믿음', experience: '삶',
  purpose: '자기계발', attitude: '자기계발', action: '도전',
};

// ── Author 파싱: "Author, Book Title" 형식 분리 ────────────────────────────
function splitAuthor(raw) {
  if (!raw) return { author: '미상', source: null };
  const comma = raw.indexOf(',');
  if (comma === -1) return { author: raw.trim(), source: null };
  return {
    author: raw.slice(0, comma).trim(),
    source: raw.slice(comma + 1).trim() || null,
  };
}

// ── 태그 변환 (최대 5개) ──────────────────────────────────────────────────────
function mapTags(englishTags, category) {
  const result = new Set();
  if (category) {
    const m = TAG_MAP[category.toLowerCase().trim()];
    if (m) result.add(m);
  }
  if (Array.isArray(englishTags)) {
    for (const t of englishTags) {
      if (result.size >= 5) break;
      const m = TAG_MAP[t.toLowerCase().trim()];
      if (m) result.add(m);
    }
  }
  return [...result];
}

// ── 메인 ──────────────────────────────────────────────────────────────────────
async function seed() {
  console.log('📂 quotes.json 로딩 중...');
  const raw = require(path.join(__dirname, '../quotes.json'));

  // 1. 중복 제거 (Quote 텍스트 기준)
  const seen = new Set();
  const unique = raw.filter((q) => {
    if (!q.Quote || seen.has(q.Quote)) return false;
    seen.add(q.Quote);
    return true;
  });

  // 2. 인기도 필터 + 내림차순 정렬
  const filtered = unique
    .filter((q) => (q.Popularity || 0) >= MIN_POP)
    .sort((a, b) => (b.Popularity || 0) - (a.Popularity || 0));

  // 3. SKIP / LIMIT 적용
  const target = filtered.slice(SKIP, Number.isFinite(LIMIT) ? SKIP + LIMIT : undefined);

  console.log(`\n📊 통계:`);
  console.log(`   원본: ${raw.length.toLocaleString()}개`);
  console.log(`   중복 제거: ${unique.length.toLocaleString()}개`);
  console.log(`   인기도 >= ${MIN_POP} 필터: ${filtered.length.toLocaleString()}개`);
  console.log(`   SKIP: ${SKIP.toLocaleString()}, LIMIT: ${Number.isFinite(LIMIT) ? LIMIT.toLocaleString() : '없음'}`);
  console.log(`   ▶ 이번 삽입 대상: ${target.length.toLocaleString()}개\n`);

  if (target.length === 0) {
    console.log('⚠️  삽입할 항목이 없습니다. --skip 또는 --min-pop 값을 확인하세요.');
    return;
  }

  const col = db.collection('quotes');
  const BATCH_SIZE = 499;  // Firestore 최대 500, 안전하게 499
  const DELAY_MS   = 200;  // 배치 간 딜레이 (Rate limit 방지)

  let inserted = 0;
  const t0 = Date.now();

  for (let i = 0; i < target.length; i += BATCH_SIZE) {
    const chunk = target.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const q of chunk) {
      const { author, source } = splitAuthor(q.Author);
      batch.set(col.doc(), {
        content:    q.Quote.replace(/\s+/g, ' ').trim(),
        author,
        source,
        language:   'en',
        isFeatured: (q.Popularity || 0) >= 0.03,  // 인기도 3% 이상 홈 화면 노출
        tags:       mapTags(q.Tags, q.Category),
        popularity: q.Popularity || 0,
        createdAt:  Timestamp.now(),
      });
    }

    await batch.commit();
    inserted += chunk.length;

    const elapsed  = ((Date.now() - t0) / 1000).toFixed(1);
    const percent  = ((inserted / target.length) * 100).toFixed(1);
    const speed    = (inserted / ((Date.now() - t0) / 1000)).toFixed(0);
    const remaining = Math.round((target.length - inserted) / speed);
    process.stdout.write(
      `\r✅ ${inserted.toLocaleString()}/${target.length.toLocaleString()} (${percent}%) | ${elapsed}s 경과 | 남은 예상 ${remaining}s  `
    );

    if (i + BATCH_SIZE < target.length) {
      await new Promise((r) => setTimeout(r, DELAY_MS));
    }
  }

  const total = ((Date.now() - t0) / 1000).toFixed(1);
  console.log(`\n\n🎉 완료! ${inserted.toLocaleString()}개 삽입 (${total}초)`);

  const nextSkip = SKIP + inserted;
  if (nextSkip < filtered.length) {
    console.log(`\n💡 내일 이어서 실행하세요:`);
    console.log(`   node seed_all.js --skip ${nextSkip}`);
    console.log(`   남은 개수: ${(filtered.length - nextSkip).toLocaleString()}개`);
  } else {
    console.log(`\n✨ quotes.json 전체 삽입 완료!`);
  }
}

seed().catch((err) => {
  console.error('\n❌ 오류:', err.message);
  process.exit(1);
});
