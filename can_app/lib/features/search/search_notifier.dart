import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/storage/user_data.dart';
import '../../core/theme/theme_notifier.dart';
import '../../shared/models/quote.dart';
import '../home/quote_repository.dart';
import 'tag_extractor.dart';

const _kRecentSearchesKey = kRecentSearchesKey;
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
  final String aiMessage;
  final List<Quote> similar;

  const SearchState({
    this.keyword = '',
    this.emotionInput = '',
    this.selectedTags = const [],
    this.recentSearches = const [],
    this.results = const AsyncValue.data([]),
    this.hasMore = false,
    this.nextOffset = 0,
    this.aiMessage = '',
    this.similar = const [],
  });

  SearchState copyWith({
    String? keyword,
    String? emotionInput,
    List<String>? selectedTags,
    List<String>? recentSearches,
    AsyncValue<List<Quote>>? results,
    bool? hasMore,
    int? nextOffset,
    String? aiMessage,
    List<Quote>? similar,
  }) =>
      SearchState(
        keyword: keyword ?? this.keyword,
        emotionInput: emotionInput ?? this.emotionInput,
        selectedTags: selectedTags ?? this.selectedTags,
        recentSearches: recentSearches ?? this.recentSearches,
        results: results ?? this.results,
        hasMore: hasMore ?? this.hasMore,
        nextOffset: nextOffset ?? this.nextOffset,
        // results 가 바뀔 때 AI 메시지를 명시하지 않으면 초기화
        aiMessage: aiMessage ?? (results != null ? '' : this.aiMessage),
        similar: similar ?? (results != null ? const [] : this.similar),
      );
}

// ---------------------------------------------------------------------------
// SearchNotifier
// ---------------------------------------------------------------------------
class SearchNotifier extends Notifier<SearchState> {
  int _requestId = 0;
  int? _loadingMoreRequest;
  int _recentRevision = 0;
  bool _disposed = false;

  @override
  SearchState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _requestId++;
    });
    ref.listen(themeNotifierProvider.select((s) => s.languageCode),
        (previous, next) {
      if (previous != next) {
        _requestId++;
        retryCurrentSearch();
      }
    });
    _loadRecentSearches();
    return const SearchState();
  }

  QuoteRepository get _repo => ref.read(quoteRepositoryProvider);
  String get _language => ref.read(themeNotifierProvider).languageCode;

  bool _isCurrent(int requestId) => !_disposed && requestId == _requestId;

  Future<void> _loadRecentSearches() async {
    final revision = _recentRevision;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed || revision != _recentRevision) return;
    final list = prefs.getStringList(_kRecentSearchesKey) ?? [];
    state = state.copyWith(recentSearches: list);
  }

  Future<void> _saveRecentSearch(String keyword) async {
    if (keyword.trim().isEmpty) return;
    _recentRevision++;
    final list = List<String>.from(state.recentSearches);
    list.remove(keyword);
    list.insert(0, keyword);
    if (list.length > _kMaxRecentSearches) list.removeLast();
    state = state.copyWith(recentSearches: list);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearchesKey, list);
  }

  Future<void> removeRecentSearch(String keyword) async {
    _recentRevision++;
    final list = List<String>.from(state.recentSearches)..remove(keyword);
    state = state.copyWith(recentSearches: list);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearchesKey, list);
  }

  /// 키워드 검색 (새 검색 시작)
  Future<void> searchByKeyword(String keyword, {bool saveRecent = true}) async {
    if (keyword.trim().isEmpty) {
      clearSearch();
      return;
    }
    final requestId = ++_requestId;
    final language = _language;
    state = state.copyWith(
      keyword: keyword,
      emotionInput: '',
      selectedTags: [],
      results: const AsyncValue.loading(),
      hasMore: false,
      nextOffset: 0,
    );
    if (saveRecent) await _saveRecentSearch(keyword);
    if (!_isCurrent(requestId)) return;
    try {
      final page = await _repo.searchByKeyword(keyword, language: language);
      if (!_isCurrent(requestId)) return;
      state = state.copyWith(
        results: AsyncValue.data(page.quotes),
        hasMore: page.hasMore,
        nextOffset: page.nextOffset,
      );
    } catch (e, st) {
      if (!_isCurrent(requestId)) return;
      state = state.copyWith(results: AsyncValue.error(e, st));
    }
  }

  /// 통합 검색: 일반 키워드/감정 문장을 단일 입력으로 처리
  Future<void> searchUnified(String input) async {
    await searchByEmotion(input);
  }

  /// 감정 문장 입력 → AI 가 실존 인물 명언 1개 추천 (실패 시 태그/키워드 검색 폴백)
  Future<void> searchByEmotion(String input, {bool saveRecent = true}) async {
    if (input.trim().isEmpty) return;
    final requestId = ++_requestId;
    final language = _language;
    final tags = TagExtractor.extract(input);
    state = state.copyWith(
      emotionInput: input,
      keyword: '',
      selectedTags: tags,
      results: const AsyncValue.loading(),
      hasMore: false,
      nextOffset: 0,
    );
    if (saveRecent) await _saveRecentSearch(input);
    if (!_isCurrent(requestId)) return;
    try {
      final ai = await _repo.recommendByEmotion(input, language: language);
      if (!_isCurrent(requestId)) return;
      if (ai != null) {
        state = state.copyWith(
          aiMessage: ai.message,
          similar: ai.similar,
          results: AsyncValue.data([ai.quote]),
          hasMore: false,
          nextOffset: 0,
        );
        return;
      }
      // 1) 태그 검색
      if (tags.isNotEmpty) {
        final page = await _repo.searchByTags(tags, language: language);
        if (!_isCurrent(requestId)) return;
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
      final byKeyword = await _repo.searchByKeyword(input, language: language);
      if (!_isCurrent(requestId)) return;
      if (byKeyword.quotes.isNotEmpty) {
        state = state.copyWith(
          keyword: input,
          selectedTags: const [],
          results: AsyncValue.data(byKeyword.quotes),
          hasMore: byKeyword.hasMore,
          nextOffset: byKeyword.nextOffset,
        );
        return;
      }

      // 3) 태그·키워드 모두 결과 없음 → 빈 결과 표시 (폴백 추천 제거)
      state = state.copyWith(
        results: const AsyncValue.data([]),
        hasMore: false,
        nextOffset: 0,
      );
    } catch (e, st) {
      if (!_isCurrent(requestId)) return;
      state = state.copyWith(results: AsyncValue.error(e, st));
    }
  }

  /// 현재 상태 기준 재시도
  Future<void> retryCurrentSearch() async {
    // 감정 검색의 키워드 폴백 상태도 원래 입력으로 다시 추천한다.
    if (state.emotionInput.isNotEmpty) {
      await searchByEmotion(state.emotionInput, saveRecent: false);
      return;
    }
    if (state.keyword.isNotEmpty) {
      await searchByKeyword(state.keyword, saveRecent: false);
      return;
    }
    if (state.selectedTags.isNotEmpty) {
      final requestId = ++_requestId;
      final language = _language;
      state = state.copyWith(
        results: const AsyncValue.loading(),
        hasMore: false,
        nextOffset: 0,
      );
      try {
        final page = await _repo.searchByTags(
          state.selectedTags,
          language: language,
        );
        if (!_isCurrent(requestId)) return;
        state = state.copyWith(
          results: AsyncValue.data(page.quotes),
          hasMore: page.hasMore,
          nextOffset: page.nextOffset,
        );
      } catch (e, st) {
        if (!_isCurrent(requestId)) return;
        state = state.copyWith(results: AsyncValue.error(e, st));
      }
    }
  }

  /// 태그 칩 직접 선택
  Future<void> searchByTag(String tag) async {
    final requestId = ++_requestId;
    final language = _language;
    state = state.copyWith(
      selectedTags: [tag],
      keyword: '',
      emotionInput: '',
      results: const AsyncValue.loading(),
      hasMore: false,
      nextOffset: 0,
    );
    try {
      final page = await _repo.searchByTags([tag], language: language);
      if (!_isCurrent(requestId)) return;
      state = state.copyWith(
        results: AsyncValue.data(page.quotes),
        hasMore: page.hasMore,
        nextOffset: page.nextOffset,
      );
    } catch (e, st) {
      if (!_isCurrent(requestId)) return;
      state = state.copyWith(results: AsyncValue.error(e, st));
    }
  }

  /// 검색 초기화 (취소 버튼)
  void clearSearch() {
    _requestId++;
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
    if (!state.hasMore ||
      state.results.isLoading ||
        _loadingMoreRequest == _requestId) {
      return;
    }
    final requestId = _requestId;
    final language = _language;
    _loadingMoreRequest = requestId;
    final current = state.results.value ?? [];
    try {
      QuotePage page;
      if (state.keyword.isNotEmpty) {
        page = await _repo.searchByKeyword(state.keyword,
            offset: state.nextOffset, language: language);
      } else {
        page = await _repo.searchByTags(state.selectedTags,
            offset: state.nextOffset, language: language);
      }
          if (!_isCurrent(requestId)) return;
      state = state.copyWith(
        results: AsyncValue.data([...current, ...page.quotes]),
        hasMore: page.hasMore,
        nextOffset: page.nextOffset,
      );
    } catch (_) {
      // 더보기 실패 시 기존 결과 유지
    } finally {
      if (_loadingMoreRequest == requestId) _loadingMoreRequest = null;
    }
  }
}

final searchNotifierProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
