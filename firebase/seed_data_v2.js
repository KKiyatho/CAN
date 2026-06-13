/**
 * Firestore 시드 데이터 v2 — quotes.json 인기 상위 명언 한국어 번역본
 *
 * 사용법:
 *   node seed_data_v2.js
 *
 * 주의: 기존 seed_data.js(v1)와 중복되지 않는 명언만 포함합니다.
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

const quotes = [
  // ── 삶·인생 ──────────────────────────────────────────────────────
  {
    content: '끝났다고 울지 마라. 그 일이 있었기에 미소 지어라.',
    author: '닥터 수스',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['행복', '삶', '긍정'],
  },
  {
    content: '삶은 한 번뿐이다. 하지만 제대로 산다면, 한 번으로 충분하다.',
    author: '매 웨스트',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['삶', '도전'],
  },
  {
    content: '삶에 대해 배운 모든 것을 세 단어로 표현할 수 있다: 그래도 계속된다.',
    author: '로버트 프로스트',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['삶', '회복', '극복'],
  },
  {
    content: '삶이란 당신이 다른 계획을 세우느라 바쁜 동안 일어나는 것이다.',
    author: '앨런 손더스',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['삶', '자기계발'],
  },
  {
    content: '사는 것은 세상에서 가장 드문 일이다. 대부분의 사람은 그저 존재할 뿐이다.',
    author: '오스카 와일드',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['삶', '철학'],
  },
  {
    content: '꿈에 빠져 살며 진짜 삶을 잊는 것은 좋지 않다.',
    author: 'J.K. 롤링',
    source: '해리 포터와 마법사의 돌',
    language: 'ko',
    isFeatured: false,
    tags: ['삶', '꿈'],
  },

  // ── 자기 자신 ────────────────────────────────────────────────────
  {
    content: '너 자신이 되어라. 다른 모든 자리는 이미 차 있다.',
    author: '오스카 와일드',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['자기계발', '자유', '개성'],
  },
  {
    content: '끊임없이 다른 무언가가 되려 하는 세상에서 자기 자신이 되는 것, 그것이 가장 위대한 성취다.',
    author: '랄프 왈도 에머슨',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['자기계발', '도전', '개성'],
  },
  {
    content: '당신 자신이 되고, 느끼는 것을 말하라. 중요한 사람은 신경 쓰지 않고, 신경 쓰는 사람은 중요하지 않으니.',
    author: '버나드 바루크',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['자기계발', '용기', '개성'],
  },
  {
    content: '진짜 당신으로서 미움받는 것이, 가짜로 사랑받는 것보다 낫다.',
    author: '앙드레 지드',
    source: '가을의 낙엽',
    language: 'ko',
    isFeatured: true,
    tags: ['자기계발', '진실', '개성'],
  },
  {
    content: '불완전함은 아름다움이다. 광기는 천재성이다. 지루하게 정상으로 사는 것보다 완전히 우스꽝스럽게 사는 것이 낫다.',
    author: '마릴린 먼로',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['자기계발', '삶', '개성'],
  },

  // ── 변화·행동 ────────────────────────────────────────────────────
  {
    content: '네가 세상에서 보고 싶은 변화 그 자체가 되어라.',
    author: '마하트마 간디',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['변화', '도전', '삶'],
  },
  {
    content: '마치 내일 죽을 것처럼 살아라. 마치 영원히 살 것처럼 배워라.',
    author: '마하트마 간디',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['자기계발', '배움', '삶'],
  },
  {
    content: '같은 일을 반복하면서 다른 결과를 기대하는 것, 그것이 바로 미치광이 짓이다.',
    author: '알버트 아인슈타인',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['자기계발', '변화', '지혜'],
  },

  // ── 두려움·용기 ──────────────────────────────────────────────────
  {
    content: '20년 후, 당신은 했던 일보다 하지 않은 일들을 더 후회할 것이다. 닻을 올리고 안전한 항구를 떠나 돛을 달아라.',
    author: 'H. 잭슨 브라운 주니어',
    source: 'P.S. 사랑해',
    language: 'ko',
    isFeatured: true,
    tags: ['도전', '용기', '자기계발'],
  },
  {
    content: '다수의 편에 서 있다면, 이제 멈추고 돌아볼 때다.',
    author: '마크 트웨인',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['용기', '개성', '지혜'],
  },
  {
    content: '무언가를 지키고 서 있지 않으면, 무엇에도 쓰러질 수 있다.',
    author: '고든 이디',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['용기', '믿음', '도전'],
  },

  // ── 사랑·관계 ────────────────────────────────────────────────────
  {
    content: '나는 이기적이고, 조급하며, 조금 불안하다. 실수도 한다. 하지만 내 최악의 모습을 견뎌내지 못한다면, 최고의 나를 가질 자격도 없다.',
    author: '마릴린 먼로',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['사랑', '자기계발', '진실'],
  },
  {
    content: '현실이 마침내 꿈보다 나아져 잠들지 못할 때, 당신이 사랑에 빠졌다는 것을 알 수 있다.',
    author: '닥터 수스',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['사랑', '행복'],
  },
  {
    content: '아무도 보지 않는 것처럼 춤추고, 상처받지 않을 것처럼 사랑하고, 아무도 듣지 않는 것처럼 노래하고, 이곳이 천국인 것처럼 살아라.',
    author: '윌리엄 퍼키',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['사랑', '삶', '행복'],
  },
  {
    content: '우리는 우리가 받을 자격이 있다고 생각하는 사랑을 받아들인다.',
    author: '스티븐 크보스키',
    source: '월플라워',
    language: 'ko',
    isFeatured: false,
    tags: ['사랑', '자기계발'],
  },
  {
    content: '나는 당신을 사랑한다. 어떻게, 언제부터, 어디서부터인지는 모르지만. 그냥 사랑한다. 아무 불만 없이, 자존심 없이, 이름도 없이.',
    author: '파블로 네루다',
    source: '사랑의 소네트 100편',
    language: 'ko',
    isFeatured: true,
    tags: ['사랑'],
  },
  {
    content: '불행한 결혼의 원인은 사랑의 부족이 아니라 우정의 부족이다.',
    author: '프리드리히 니체',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['사랑', '우정', '철학'],
  },

  // ── 우정 ─────────────────────────────────────────────────────────
  {
    content: '우정은 한 사람이 다른 사람에게 "뭐? 너도? 나만 그런 줄 알았는데..."라고 말하는 순간 태어난다.',
    author: 'C.S. 루이스',
    source: '네 가지 사랑',
    language: 'ko',
    isFeatured: true,
    tags: ['우정', '사랑'],
  },
  {
    content: '친구란 당신의 모든 것을 알면서도 여전히 당신을 사랑하는 사람이다.',
    author: '엘버트 허버드',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['우정', '사랑'],
  },
  {
    content: '좋은 친구, 좋은 책, 그리고 졸리는 양심: 이것이 이상적인 삶이다.',
    author: '마크 트웨인',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['우정', '독서', '삶'],
  },

  // ── 진실·지혜 ────────────────────────────────────────────────────
  {
    content: '두 가지는 무한하다: 우주와 인간의 어리석음. 그런데 우주에 대해서는 확신할 수 없다.',
    author: '알버트 아인슈타인',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['지혜', '철학', '유머'],
  },
  {
    content: '진실을 말하면 아무것도 기억할 필요가 없다.',
    author: '마크 트웨인',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['진실', '지혜'],
  },
  {
    content: '한 사람이 어떤 사람인지 알고 싶다면, 그가 아랫사람을 어떻게 대하는지 잘 보아라.',
    author: 'J.K. 롤링',
    source: '해리 포터와 불의 잔',
    language: 'ko',
    isFeatured: true,
    tags: ['지혜', '진실', '삶'],
  },
  {
    content: '바보는 자신이 현명하다고 생각하지만, 현명한 사람은 자신이 바보임을 안다.',
    author: '윌리엄 셰익스피어',
    source: '뜻대로 하세요',
    language: 'ko',
    isFeatured: false,
    tags: ['지혜', '철학'],
  },
  {
    content: '바보라고 생각될 위험을 감수하며 침묵하는 것이, 말하여 그 의심을 확인시켜 주는 것보다 낫다.',
    author: '모리스 스위처',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['지혜', '침묵'],
  },
  {
    content: '사랑의 반대는 증오가 아니라 무관심이다. 예술의 반대는 추함이 아니라 무관심이다.',
    author: '엘리 위젤',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['지혜', '사랑', '철학'],
  },
  {
    content: '어제는 역사, 내일은 미스터리, 오늘은 하느님의 선물. 그래서 오늘을 선물(Present)이라고 부른다.',
    author: '빌 킨',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['지혜', '삶', '행복'],
  },

  // ── 어둠·빛 ──────────────────────────────────────────────────────
  {
    content: '어둠은 어둠을 몰아낼 수 없다. 오직 빛만이 할 수 있다. 증오는 증오를 몰아낼 수 없다. 오직 사랑만이 할 수 있다.',
    author: '마틴 루터 킹 주니어',
    source: '희망의 증언',
    language: 'ko',
    isFeatured: true,
    tags: ['사랑', '희망', '삶'],
  },
  {
    content: '우리 모두는 진흙 속에 있지만, 그 중 일부는 별을 바라보고 있다.',
    author: '오스카 와일드',
    source: '윈더미어 부인의 부채',
    language: 'ko',
    isFeatured: true,
    tags: ['희망', '삶', '도전'],
  },

  // ── 성공·실패 ────────────────────────────────────────────────────
  {
    content: '나는 실패한 게 아니다. 그저 잘 안 되는 방법 1만 가지를 발견했을 뿐이다.',
    author: '토마스 에디슨',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['성공', '도전', '극복'],
  },
  {
    content: '삶을 사는 방법은 두 가지뿐이다. 하나는 아무것도 기적이 아닌 것처럼, 다른 하나는 모든 것이 기적인 것처럼.',
    author: '알버트 아인슈타인',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['성공', '삶', '지혜'],
  },
  {
    content: '해리, 우리가 진정 어떤 사람인지를 보여주는 것은 우리의 능력이 아니라 우리의 선택이다.',
    author: 'J.K. 롤링',
    source: '해리 포터와 비밀의 방',
    language: 'ko',
    isFeatured: true,
    tags: ['성공', '도전', '자기계발'],
  },

  // ── 자존감 ───────────────────────────────────────────────────────
  {
    content: '당신의 동의 없이는 아무도 당신에게 열등감을 느끼게 할 수 없다.',
    author: '엘리너 루스벨트',
    source: '나의 이야기',
    language: 'ko',
    isFeatured: true,
    tags: ['자기계발', '용기', '자존감'],
  },
  {
    content: '여자는 티백과 같다. 뜨거운 물에 넣어 보기 전까지는 얼마나 강한지 알 수 없다.',
    author: '엘리너 루스벨트',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['용기', '자기계발'],
  },

  // ── 우정·연결 ────────────────────────────────────────────────────
  {
    content: '내 앞에서 걷지 마라, 내가 따라가지 못할 수도 있다. 내 뒤에서도 걷지 마라, 내가 이끌지 못할 수도 있다. 그냥 내 곁에서 걷고, 나의 친구가 되어다오.',
    author: '알베르 카뮈',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['우정', '사랑', '삶'],
  },
  {
    content: '사람들은 당신이 한 말을 잊고, 행동도 잊지만, 당신이 그들에게 어떤 감정을 느끼게 했는지는 절대 잊지 않는다.',
    author: '마야 안젤루',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['삶', '지혜', '사랑'],
  },

  // ── 독서·지식 ────────────────────────────────────────────────────
  {
    content: '책이 없는 방은 영혼 없는 몸과 같다.',
    author: '마르쿠스 키케로',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['독서', '지혜', '배움'],
  },
  {
    content: '읽을 책은 너무 많고, 시간은 너무 적다.',
    author: '프랭크 자파',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['독서', '시간관리'],
  },
  {
    content: '책을 읽지 않는 사람은 읽을 수 없는 사람보다 나을 것이 없다.',
    author: '마크 트웨인',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['독서', '배움'],
  },
  {
    content: '나는 상상력을 자유롭게 끌어낼 수 있을 만큼의 예술가이다. 지식보다 상상력이 더 중요하다.',
    author: '알버트 아인슈타인',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['배움', '창의력', '지혜'],
  },
  {
    content: '동화는 진실 이상이다. 용이 존재한다고 말해서가 아니라, 용은 이길 수 있다고 말해 주기 때문이다.',
    author: '닐 게이먼',
    source: '코럴라인',
    language: 'ko',
    isFeatured: false,
    tags: ['희망', '꿈', '용기'],
  },
  {
    content: '그가 책을 읽는 동안, 나는 잠드는 것처럼 사랑에 빠졌다. 처음엔 천천히, 그러다 한꺼번에.',
    author: '존 그린',
    source: '잘못은 우리 별에 있어',
    language: 'ko',
    isFeatured: false,
    tags: ['사랑', '독서'],
  },

  // ── 음악·예술 ────────────────────────────────────────────────────
  {
    content: '음악 없이는 삶은 실수다.',
    author: '프리드리히 니체',
    source: '우상의 황혼',
    language: 'ko',
    isFeatured: true,
    tags: ['삶', '음악', '철학'],
  },

  // ── 용서·관용 ────────────────────────────────────────────────────
  {
    content: '항상 적을 용서하라. 그것이 그들을 가장 짜증나게 하는 일이다.',
    author: '오스카 와일드',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['용서', '지혜', '유머'],
  },

  // ── 모험·탐험 ────────────────────────────────────────────────────
  {
    content: '금이라고 모두 빛나지는 않는다. 방랑하는 모든 이가 길을 잃은 것은 아니다.',
    author: 'J.R.R. 톨킨',
    source: '반지의 제왕: 반지 원정대',
    language: 'ko',
    isFeatured: true,
    tags: ['도전', '삶', '희망'],
  },
  {
    content: '내가 가려 했던 곳에 가지 않았을 수도 있지만, 결국 내가 있어야 할 곳에 도달한 것 같다.',
    author: '더글러스 애덤스',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['삶', '도전', '희망'],
  },

  // ── 철학 ─────────────────────────────────────────────────────────
  {
    content: '모든 것에는 이유가 있다고 믿는다. 사람들은 변하게 해 주고, 배울 수 있게 해 주고, 더 강해지게 해 준다.',
    author: '마릴린 먼로',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['삶', '철학', '자기계발'],
  },
  {
    content: '내일 할 수 있는 일을 모레로 미루지 마라.',
    author: '마크 트웨인',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['자기계발', '시간관리', '유머'],
  },
];

async function seed() {
  const col = db.collection('quotes');
  let count = 0;

  for (const q of quotes) {
    await col.add({ ...q, createdAt: Timestamp.now() });
    count++;
    console.log(`✅ [${count}/${quotes.length}] ${q.author}: ${q.content.substring(0, 30)}...`);
  }

  console.log(`\n🎉 완료! 총 ${count}개의 명언이 Firestore에 추가되었습니다.`);
}

seed().catch(console.error);
