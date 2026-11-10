import 'dart:async';
import 'dart:convert';

import 'package:can_app/core/theme/i18n.dart';
import 'package:can_app/core/theme/theme_notifier.dart';
import 'package:can_app/features/home/home_notifier.dart';
import 'package:can_app/features/home/quote_repository.dart';
import 'package:can_app/features/search/category_detail_notifier.dart';
import 'package:can_app/features/search/search_labels.dart';
import 'package:can_app/features/search/search_notifier.dart';
import 'package:can_app/features/search/tag_extractor.dart';
import 'package:can_app/features/wallpaper/wallpaper_screen.dart';
import 'package:can_app/shared/models/quote.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Theme extends ThemeNotifier {
  @override
  ThemeState build() => const ThemeState(colorIndex: 0, isDark: false);

  void language(String code) => state = state.copyWith(languageCode: code);

  void color() => state = state.copyWith(colorIndex: 1);
}

class _Request<T> {
  _Request(this.language, this.input, this.offset);
  final String language;
  final String input;
  final int offset;
  final result = Completer<T>();
}

class _Repo extends QuoteRepository {
  final featured = <_Request<Quote>>[];
  final keywords = <_Request<QuotePage>>[];
  final tags = <_Request<QuotePage>>[];
  final categories = <_Request<TagPageResult>>[];
  final recommendations = <_Request<AiRecommendation?>>[];

  Future<T> _request<T>(List<_Request<T>> requests, String language,
      String input, int offset) {
    final request = _Request<T>(language, input, offset);
    requests.add(request);
    return request.result.future;
  }

  @override
  Future<Quote> fetchFeaturedQuote({String language = 'ko'}) =>
      _request(featured, language, '', 0);

  @override
  Future<QuotePage> searchByKeyword(String keyword,
          {int offset = 0, int limit = 20, String language = 'ko'}) =>
      _request(keywords, language, keyword, offset);

  @override
  Future<QuotePage> searchByTags(List<String> value,
          {int offset = 0, int limit = 20, String language = 'ko'}) =>
      _request(tags, language, value.join(','), offset);

  @override
  Future<TagPageResult> fetchByTagPaginated(String tag,
          {Object? lastDoc, int offset = 0, int limit = 20,
          String language = 'ko'}) =>
      _request(categories, language, tag, offset);

  @override
  Future<AiRecommendation?> recommendByEmotion(String input,
          {String language = 'ko'}) =>
      _request(recommendations, language, input, 0);
}

Quote _quote(String language, [String id = 'quote']) => Quote(
      id: '${id}_$language',
      content: '$language content $id',
      author: '$language author',
      language: language,
      isFeatured: false,
      tags: const ['사랑', 'job:철학자'],
      createdAt: DateTime(2026),
    );

QuotePage _page(String language, {bool hasMore = false}) => QuotePage(
      quotes: [_quote(language)], hasMore: hasMore, nextOffset: 1);

TagPageResult _category(String language, {bool hasMore = false}) =>
    TagPageResult(quotes: [_quote(language)], hasMore: hasMore, nextOffset: 1);

// SharedPreferences 캐시와 provider의 마이크로태스크를 완료한다.
Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repo repo;
  late ProviderContainer container;
  late _Theme theme;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = _Repo();
    container = ProviderContainer(overrides: [
      quoteRepositoryProvider.overrideWithValue(repo),
      themeNotifierProvider.overrideWith(_Theme.new),
    ]);
    theme = container.read(themeNotifierProvider.notifier) as _Theme;
  });
  tearDown(() => container.dispose());

  test('home switches immediately, coalesces pending reload and ignores old quote',
      () async {
    container.read(homeNotifierProvider);
    await _flush();
    expect(repo.featured.single.language, 'ko');
    theme.language('en');
    final duplicate = container.read(homeNotifierProvider.notifier).loadQuote();
    expect(repo.featured.map((r) => r.language), ['ko', 'en']);
    expect(container.read(homeNotifierProvider).quote.isLoading, isTrue);
    repo.featured.last.result.complete(_quote('en'));
    await duplicate;
    repo.featured.first.result.complete(_quote('ko'));
    await _flush();
    expect(container.read(homeNotifierProvider).quote.requireValue.language, 'en');
    theme.color();
    expect(repo.featured.length, 2);
  });

  test('keyword switch preserves input/history and ignores stale errors', () async {
    final notifier = container.read(searchNotifierProvider.notifier);
    await _flush();
    final old = notifier.searchByKeyword('my unchanged input');
    await _flush();
    theme.language('en');
    await _flush();
    expect(repo.keywords.map((r) => r.language), ['ko', 'en']);
    expect(container.read(searchNotifierProvider).results.isLoading, isTrue);
    repo.keywords.last.result.complete(_page('en'));
    await _flush();
    repo.keywords.first.result.completeError(StateError('old language'));
    await old;
    final state = container.read(searchNotifierProvider);
    expect(state.keyword, 'my unchanged input');
    expect(state.recentSearches, ['my unchanged input']);
    expect(state.results.requireValue.single.language, 'en');
    theme.color();
    expect(repo.keywords.length, 2);
  });

  test('emotion ignores stale AI message and similar quotes without fallback',
      () async {
    final notifier = container.read(searchNotifierProvider.notifier);
    await _flush();
    final old = notifier.searchUnified('불안한 interview');
    await _flush();
    theme.language('en');
    await _flush();
    repo.recommendations.last.result.complete(AiRecommendation(
      quote: _quote('en'), similar: [_quote('en', 'similar')], message: 'English',
    ));
    await _flush();
    repo.recommendations.first.result.complete(null);
    await old;
    final state = container.read(searchNotifierProvider);
    expect(state.emotionInput, '불안한 interview');
    expect(state.aiMessage, 'English');
    expect(state.similar.single.language, 'en');
    expect(state.recentSearches, ['불안한 interview']);
    expect(repo.tags, isEmpty);
    expect(repo.keywords, isEmpty);
  });

  test('emotion tag fallback is reissued with canonical tags in English', () async {
    final notifier = container.read(searchNotifierProvider.notifier);
    await _flush();
    final old = notifier.searchUnified('사랑');
    await _flush();
    repo.recommendations.first.result.complete(null);
    await _flush();
    theme.language('en');
    await _flush();
    repo.recommendations.last.result.complete(null);
    await _flush();
    expect(repo.tags.map((r) => '${r.language}:${r.input}'), ['ko:사랑', 'en:사랑']);
    repo.tags.last.result.complete(_page('en'));
    await _flush();
    repo.tags.first.result.complete(_page('ko'));
    await old;
    expect(container.read(searchNotifierProvider).results.requireValue.single.language, 'en');
  });

  test('tag pagination cannot append old language or duplicate a pending page',
      () async {
    final notifier = container.read(searchNotifierProvider.notifier);
    final initial = notifier.searchByTag('사랑');
    repo.tags.first.result.complete(_page('ko', hasMore: true));
    await initial;
    final more = notifier.loadMore();
    await notifier.loadMore();
    expect(repo.tags.length, 2);
    theme.language('en');
    expect(repo.tags.last.input, '사랑');
    expect(repo.tags.last.offset, 0);
    repo.tags.last.result.complete(_page('en'));
    await _flush();
    repo.tags[1].result.complete(_page('ko'));
    await more;
    expect(container.read(searchNotifierProvider).selectedTags, ['사랑']);
    expect(container.read(searchNotifierProvider).results.requireValue.single.language, 'en');
  });

  test('clear cancels pending search but preserves recent searches', () async {
    final notifier = container.read(searchNotifierProvider.notifier);
    await _flush();
    final pending = notifier.searchByKeyword('keep history');
    await _flush();
    notifier.clearSearch();
    repo.keywords.single.result.complete(_page('ko'));
    await pending;
    expect(container.read(searchNotifierProvider).results.requireValue, isEmpty);
    expect(container.read(searchNotifierProvider).recentSearches, ['keep history']);
  });

  test('category resets offset, ignores old page, and uses per-language cache',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quote_cache_tag_en_job:철학자',
        jsonEncode([_quote('en', 'cached').toMap()]));
    final provider = categoryDetailProvider('job:철학자');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await _flush();
    repo.categories.first.result.complete(_category('ko', hasMore: true));
    await _flush();
    final oldMore = container.read(provider.notifier).loadMore();
    theme.language('en');
    expect(container.read(provider).quotes, isEmpty);
    await _flush();
    expect(container.read(provider).quotes.single.language, 'en');
    expect(repo.categories.last.language, 'en');
    expect(repo.categories.last.input, 'job:철학자');
    expect(repo.categories.last.offset, 0);
    repo.categories.last.result.complete(_category('en'));
    await _flush();
    repo.categories[1].result.complete(_category('ko'));
    await oldMore;
    expect(container.read(provider).quotes.single.language, 'en');
    expect(container.read(provider).isLoadingMore, isFalse);
  });

  test('pending first category request cannot replace new language', () async {
    final provider = categoryDetailProvider('사랑');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await _flush();
    theme.language('en');
    await _flush();
    repo.categories.last.result.complete(_category('en'));
    await _flush();
    repo.categories.first.result.completeError(StateError('stale failure'));
    await _flush();
    expect(container.read(provider).quotes.single.language, 'en');
    expect(container.read(provider).error, isNull);
  });

  test('all category and emotion tags have English display labels only', () {
    for (final tag in [...TagExtractor.allTags,
      'job:철학자', 'job:기업가', 'job:작가', 'job:과학자',
      'job:예술가', 'job:운동선수', 'job:정치가', 'job:종교인']) {
      expect(localizedSearchLabel('en', tag), isNot(matches(RegExp('[가-힣]'))));
      expect(localizedSearchLabel('ko', tag), tag.replaceFirst('job:', ''));
    }
  });

  testWidgets('wallpaper reload preserves custom text and selected background',
      (tester) async {
    // 웹 캔버스는 네트워크 폰트 대신 내장 폰트를 사용한다.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WallpaperScreen()),
    ));
    repo.featured.single.result.complete(_quote('ko'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(I18n.t('ko', 'wallpaper.solid')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(I18n.t('ko', 'wallpaper.customInput')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'My own words');
    await tester.tap(find.text(I18n.t('ko', 'wallpaper.apply')));
    await tester.pumpAndSettle();
    theme.language('en');
    await tester.pump();
    theme.language('ko');
    await tester.pump();
    repo.featured.last.result.complete(_quote('ko', 'new'));
    await tester.pumpAndSettle();
    repo.featured[1].result.complete(_quote('en', 'stale'));
    await tester.pumpAndSettle();
    expect(find.text('My own words'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) =>
      widget is Container && widget.color == const Color(0xFF1F1F1F)),
      findsOneWidget);
    await tester.tap(find.byTooltip(I18n.t('ko', 'wallpaper.customInput')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(I18n.t('ko', 'wallpaper.restoreQuote')));
    await tester.pumpAndSettle();
    expect(find.text('"ko content new"'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !kIsWeb);
}