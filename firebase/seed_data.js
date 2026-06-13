/**
 * Firestore 시드 데이터 스크립트 (모듈화 및 안정성 개선 버전)
 *
 * 사용법:
 *   1. npm install firebase-admin
 *   2. Firebase 콘솔 > 프로젝트 설정 > 서비스 계정 > 새 비공개 키 생성
 *      → serviceAccountKey.json 파일을 이 폴더에 저장
 *   3. node seed_data.js
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

const quotes = [
  {
    content: '당신이 할 수 있다고 믿든, 없다고 믿든 당신의 믿음은 옳다.',
    author: '헨리 포드',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['도전', '자기계발', '믿음'],
    createdAt: Timestamp.now(),
  },
  {
    content: '성공은 최종 목적지가 아니며, 실패도 치명적이지 않다. 계속하는 용기가 중요하다.',
    author: '윈스턴 처칠',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['성공', '도전', '용기'],
    createdAt: Timestamp.now(),
  },
  {
    content: '인생에서 가장 위험한 것은 지나치게 신중한 것이다.',
    author: '네드 스코필드',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['도전', '용기'],
    createdAt: Timestamp.now(),
  },
  {
    content: '오늘 할 수 있는 일을 내일로 미루지 마라.',
    author: '벤자민 프랭클린',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['자기계발', '시간관리'],
    createdAt: Timestamp.now(),
  },
  {
    content: '당신의 시간은 한정되어 있다. 다른 사람의 삶을 사는 데 낭비하지 마라.',
    author: '스티브 잡스',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['자기계발', '삶'],
    createdAt: Timestamp.now(),
  },
  {
    content: '천 리 길도 한 걸음부터 시작된다.',
    author: '노자',
    source: '도덕경',
    language: 'ko',
    isFeatured: true,
    tags: ['시작', '도전'],
    createdAt: Timestamp.now(),
  },
  {
    content: '넘어진 횟수가 아니라 다시 일어선 횟수가 중요하다.',
    author: '넬슨 만델라',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['회복', '용기', '극복'],
    createdAt: Timestamp.now(),
  },
  {
    content: '행복은 목적지가 아니라 여행 방식이다.',
    author: '마가렛 리 런벡',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['행복', '삶'],
    createdAt: Timestamp.now(),
  },
  {
    content: '두려움은 꿈을 죽이지 못한다. 두려움에 굴복하는 것이 꿈을 죽인다.',
    author: '베르나르 베르베르',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['두려움', '꿈', '도전'],
    createdAt: Timestamp.now(),
  },
  {
    content: '가장 어두운 밤도 끝나고, 해는 다시 떠오른다.',
    author: '빅토르 위고',
    source: '레미제라블',
    language: 'ko',
    isFeatured: true,
    tags: ['희망', '극복'],
    createdAt: Timestamp.now(),
  },
  {
    content: '실패는 성공의 어머니다.',
    author: '토마스 에디슨',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['실패', '성공', '도전'],
    createdAt: Timestamp.now(),
  },
  {
    content: '지금 이 순간이 당신의 인생에서 가장 젊은 순간이다.',
    author: '익명',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['시간', '삶'],
    createdAt: Timestamp.now(),
  },
  {
    content: '변화를 두려워하지 마라. 나비가 되기 전에 번데기가 되어야 한다.',
    author: '익명',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['변화', '성장'],
    createdAt: Timestamp.now(),
  },
  {
    content: '작은 진보도 진보다.',
    author: '익명',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['성장', '자기계발'],
    createdAt: Timestamp.now(),
  },
  {
    content: '어제는 역사, 내일은 미스터리, 오늘은 선물이다. 그래서 현재라 부른다.',
    author: '빌 킨',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['삶', '현재'],
    createdAt: Timestamp.now(),
  },
  {
    content: '당신이 원하는 변화가 되어라.',
    author: '마하트마 간디',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['변화', '리더십'],
    createdAt: Timestamp.now(),
  },
  {
    content: '모든 것은 마음먹기에 달려 있다.',
    author: '마르쿠스 아우렐리우스',
    source: '명상록',
    language: 'ko',
    isFeatured: false,
    tags: ['마음', '자기계발'],
    createdAt: Timestamp.now(),
  },
  {
    content: '고통 없이는 얻을 것도 없다.',
    author: '벤자민 프랭클린',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['성장', '노력'],
    createdAt: Timestamp.now(),
  },
  {
    content: '나 자신을 알라.',
    author: '소크라테스',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['자기계발', '지혜'],
    createdAt: Timestamp.now(),
  },
  {
    content: '지식은 힘이다.',
    author: '프란시스 베이컨',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['지식', '성장'],
    createdAt: Timestamp.now(),
  },
  {
    content: '불가능이란 아무것도 아니다.',
    author: '무하마드 알리',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['도전', '믿음', '성공'],
    createdAt: Timestamp.now(),
  },
  {
    content: '꿈을 꾸는 사람에게 불가능이란 없다.',
    author: '월트 디즈니',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['꿈', '희망'],
    createdAt: Timestamp.now(),
  },
  {
    content: '인생은 자전거 타기와 같다. 균형을 유지하려면 계속 움직여야 한다.',
    author: '알베르트 아인슈타인',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['삶', '도전'],
    createdAt: Timestamp.now(),
  },
  {
    content: '스스로를 믿어라. 당신 안에 있는 힘을 믿어라.',
    author: '엘리너 루스벨트',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['믿음', '자기계발'],
    createdAt: Timestamp.now(),
  },
  {
    content: '오늘 심은 나무 그늘에서 내일 쉰다.',
    author: '영국 속담',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['준비', '미래'],
    createdAt: Timestamp.now(),
  },
  {
    content: '당신이 멈추지 않는 한 얼마나 천천히 가느냐는 중요하지 않다.',
    author: '공자',
    source: null,
    language: 'ko',
    isFeatured: true,
    tags: ['도전', '인내'],
    createdAt: Timestamp.now(),
  },
  {
    content: '웃음은 모든 질병에 대한 최고의 약이다.',
    author: '히포크라테스',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['행복', '건강'],
    createdAt: Timestamp.now(),
  },
  {
    content: '자신을 사랑하는 것이 평생의 로맨스의 시작이다.',
    author: '오스카 와일드',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['사랑', '자기계발'],
    createdAt: Timestamp.now(),
  },
  {
    content: '무언가를 배우기에 늦은 때는 없다.',
    author: '조지 엘리엇',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['성장', '배움'],
    createdAt: Timestamp.now(),
  },
  {
    content: '최고의 복수는 엄청난 성공이다.',
    author: '프랭크 시나트라',
    source: null,
    language: 'ko',
    isFeatured: false,
    tags: ['성공', '동기부여'],
    createdAt: Timestamp.now(),
  },
];

async function seedData() {
  console.log(`총 ${quotes.length}개의 명언을 Firestore에 추가합니다...`);
  const batch = db.batch();

  quotes.forEach((quote) => {
    const docRef = db.collection('quotes').doc();
    batch.set(docRef, quote);
  });

  await batch.commit();
  console.log('✅ 시드 데이터 삽입 완료!');
  process.exit(0);
}

seedData().catch((err) => {
  console.error('❌ 오류:', err);
  process.exit(1);
});
