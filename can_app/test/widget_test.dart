import 'package:can_app/features/home/quote_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = QuoteRepository();
  const jobs = ['철학자', '기업가', '작가', '과학자', '예술가', '운동선수', '정치가', '종교인'];

  test('모든 직업 카테고리에 실존 인물 명언이 있다', () async {
    for (final job in jobs) {
      final r = await repo.fetchByTagPaginated('job:$job', limit: 1000);
      expect(r.quotes.length, greaterThanOrEqualTo(20), reason: job);
      expect(r.quotes.every((q) => q.author != 'CAN' && q.author.isNotEmpty), isTrue);
    }
  });

  test('한국어/영어 명언이 모두 로드되고 저자가 있다', () async {
    for (final lang in ['ko', 'en']) {
      final q = await repo.fetchFeaturedQuote(language: lang);
      expect(q.language, lang);
      expect(q.author.trim(), isNotEmpty);
    }
  });

  test('키워드 검색은 결과 없으면 빈 목록을 반환한다', () async {
    final r = await repo.searchByKeyword('zzzzqqqq없는말');
    expect(r.quotes, isEmpty);
  });
}
