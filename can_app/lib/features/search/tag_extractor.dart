/// 감정/상황 입력 문장 → 사전 정의 태그 목록으로 변환하는 유틸
///
/// MVP에서는 키워드 포함 여부로 간단하게 매칭합니다.
/// 이후 pgvector 기반 유사도 검색으로 교체 가능하도록 인터페이스를 분리합니다.
class TagExtractor {
  TagExtractor._();

  /// 태그 → 매칭 키워드 목록
  static const Map<String, List<String>> _tagKeywords = {
    '불안': ['불안', '걱정', '두렵', '무서', '긴장', '떨려', '초조', '겁'],
    '지침': ['지쳐', '지치', '힘들', '포기', '그만', '지겨', '피곤', '번아웃', '쉬고'],
    '도전': ['도전', '목표', '시작', '해보', '용기', '할 수 있', '모험', '새로운'],
    '면접': ['면접', '취업', '입사', '채용', '합격', '탈락', '이력'],
    '관계': ['관계', '친구', '연인', '가족', '갈등', '혼자', '외로', '사람', '소통'],
    '자기계발': ['공부', '성장', '발전', '노력', '열심히', '배우', '향상', '습관'],
  };

  /// 입력 문장에서 매칭되는 태그 목록 반환
  static List<String> extract(String input) {
    if (input.trim().isEmpty) return [];
    final lower = input.toLowerCase();
    return _tagKeywords.entries
        .where((entry) => entry.value.any((kw) => lower.contains(kw)))
        .map((entry) => entry.key)
        .toList();
  }

  /// 전체 태그 목록 (검색 탭 칩 UI용)
  static List<String> get allTags => _tagKeywords.keys.toList();
}
