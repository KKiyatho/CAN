/// 표시 언어만 변환하며 저장·검색용 한국어 태그는 변경하지 않는다.
String localizedSearchLabel(String lang, String tag) {
  final label = tag.startsWith('job:') ? tag.substring(4) : tag;
  if (lang != 'en') return label;
  const labels = {
    '철학자': 'Philosophers',
    '기업가': 'Entrepreneurs',
    '작가': 'Writers',
    '과학자': 'Scientists',
    '예술가': 'Artists',
    '운동선수': 'Athletes',
    '정치가': 'Politicians',
    '종교인': 'Religious',
    '사랑': 'Love',
    '행복': 'Happiness',
    '자기계발': 'Self Growth',
    '삶': 'Life',
    '불안': 'Anxiety',
    '지침': 'Exhaustion',
    '면접': 'Interview',
    '관계': 'Relationships',
    '철학': 'Philosophy',
    '성공': 'Success',
    '독서': 'Reading',
    '지혜': 'Wisdom',
    '창의력': 'Creativity',
    '도전': 'Challenge',
    '용기': 'Courage',
    '믿음': 'Faith',
  };
  return labels[label] ?? label;
}