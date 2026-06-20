import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/theme_notifier.dart';
import '../../shared/models/quote.dart';
import '../home/quote_repository.dart';
import 'tag_extractor.dart';

const _kRecentSearchesKey = 'recent_searches';
const _kMaxRecentSearches = 5;
// ---------------------------------------------------------------------------
// SearchState
// ---------------------------------------------------------------------------
class SearchState {
  final String keyword;
  final String emotionInput;
  final List<String> selectedTags;
  final List<String> recentSearches;
  final AsyncValue<List<Quote>> results;
  final bool hasMore;
  final int nextOffset;

  const SearchState({
    this.keyword = '',
    this.emotionInput = '',
    this.selectedTags = const [],
    this.recentSearches = const [],
    this.results = const AsyncValue.data([]),
    this.hasMore = false,
    this.nextOffset = 0,
  });

  SearchState copyWith({
    String? keyword,
    String? emotionInput,
    List<String>? selectedTags,
    List<String>? recentSearches,
    AsyncValue<List<Quote>>? results,
    bool? hasMore,
    int? nextOffset,
  }) =>
      SearchState(
        keyword: keyword ?? this.keyword,
        emotionInput: emotionInput ?? this.emotionInput,
        selectedTags: selectedTags ?? this.selectedTags,
        recentSearches: recentSearches ?? this.recentSearches,
        results: results ?? this.results,
        hasMore: hasMore ?? this.hasMore,
        nextOffset: nextOffset ?? this.nextOffset,
      );
}

// ---------------------------------------------------------------------------
// SearchNotifier
// ---------------------------------------------------------------------------
class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() {
    _loadRecentSearches();
    return const SearchState();
  }

  QuoteRepository get _repo => ref.read(quoteRepositoryProvider);
  String get _language => ref.read(themeNotifierProvider).languageCode;

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecentSearchesKey) ?? [];
    state = state.copyWith(recentSearches: list);
  }

  Future<void> _saveRecentSearch(String keyword) async {
    if (keyword.trim().isEmpty) return;
    final list = List<String>.from(state.recentSearches);
    list.remove(keyword);
    list.insert(0, keyword);
    if (list.length > _kMaxRecentSearches) list.removeLast();
    state = state.copyWith(recentSearches: list);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearchesKey, list);
  }

  Future<void> removeRecentSearch(String keyword) async {
    final list = List<String>.from(state.recentSearches)..remove(keyword);
    state = state.copyWith(recentSearches: list);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearchesKey, list);
  }

  /// 키워드 검색 (새 검색 시작)
  Future<void> searchByKeyword(String keyword) async {
    if (keyword.trim().isEmpty) {
      state = state.copyWith(
          results: const AsyncValue.data([]), hasMore: false, nextOffset: 0);
      return;
    }
    state = state.copyWith(
      keyword: keyword,
      emotionInput: '',
      selectedTags: [],
      results: const AsyncValue.loading(),
      hasMore: false,
      nextOffset: 0,
    );
    await _saveRecentSearch(keyword);
    try {
      final page = await _repo.searchByKeyword(keyword, language: _language);
      state = state.copyWith(
        results: AsyncValue.data(page.quotes),
        hasMore: page.hasMore,
        nextOffset: page.nextOffset,
      );
    } catch (e, st) {
      state = state.copyWith(results: AsyncValue.error(e, st));
    }
  }

  /// 감정 문장 입력 → 태그 추출 → 태그 검색
  Future<void> searchByEmotion(String input) async {
    if (input.trim().isEmpty) return;
    final tags = TagExtractor.extract(input);
    state = state.copyWith(
      emotionInput: input,
      keyword: '',
      selectedTags: tags,
      results: const AsyncValue.loading(),
      hasMore: false,
      nextOffset: 0,
    );
    try {
      // 1) 태그 검색
      if (tags.isNotEmpty) {
        final page = await _repo.searchByTags(tags, language: _language);
        if (page.quotes.isNotEmpty) {
          state = state.copyWith(
            results: AsyncValue.data(page.quotes),
            hasMore: page.hasMore,
            nextOffset: page.nextOffset,
          );
          return;
        }
      }

      // 2) 키워드 검색
      final byKeyword = await _repo.searchByKeyword(input, language: _language);
      if (byKeyword.quotes.isNotEmpty) {
        state = state.copyWith(
          keyword: input,
          selectedTags: const [],
          results: AsyncValue.data(byKeyword.quotes),
          hasMore: byKeyword.hasMore,
          nextOffset: byKeyword.nextOffset,
        );
        await _saveRecentSearch(input);
        return;
      }

      // 3) 기본 추천 태그 폴백
      final fallbackTags = TagExtractor.fallbackTags(input);
      final byFallback =
          await _repo.searchByTags(fallbackTags, language: _language);
      state = state.copyWith(
        selectedTags: fallbackTags,
        results: AsyncValue.data(byFallback.quotes),
        hasMore: byFallback.hasMore,
        nextOffset: byFallback.nextOffset,
      );
    } catch (e, st) {
      state = state.copyWith(results: AsyncValue.error(e, st));
    }
  }

  /// 태그 칩 직접 선택
  Future<void> searchByTag(String tag) async {
    state = state.copyWith(
      selectedTags: [tag],
      keyword: '',
      emotionInput: '',
      results: const AsyncValue.loading(),
      hasMore: false,
      nextOffset: 0,
    );
    try {
      final page = await _repo.searchByTags([tag], language: _language);
      state = state.copyWith(
        results: AsyncValue.data(page.quotes),
        hasMore: page.hasMore,
        nextOffset: page.nextOffset,
      );
    } catch (e, st) {
      state = state.copyWith(results: AsyncValue.error(e, st));
    }
  }

  /// 검색 초기화 (취소 버튼)
  void clearSearch() {
    state = state.copyWith(
      keyword: '',
      emotionInput: '',
      selectedTags: [],
      results: const AsyncValue.data([]),
      hasMore: false,
      nextOffset: 0,
    );
  }

  /// 다음 페이지 로드 (무한 스크롤)
  Future<void> loadMore() async {
    if (!state.hasMore) return;
    final current = state.results.value ?? [];
    try {
      QuotePage page;
      if (state.keyword.isNotEmpty) {
        page = await _repo.searchByKeyword(state.keyword,
            offset: state.nextOffset, language: _language);
      } else {
        page = await _repo.searchByTags(state.selectedTags,
            offset: state.nextOffset, language: _language);
      }
      state = state.copyWith(
        results: AsyncValue.data([...current, ...page.quotes]),
        hasMore: page.hasMore,
        nextOffset: page.nextOffset,
      );
    } catch (_) {
      // 더보기 실패 시 기존 결과 유지
    }
  }
}

final searchNotifierProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
