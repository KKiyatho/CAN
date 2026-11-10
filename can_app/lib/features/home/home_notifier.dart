import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_notifier.dart';
import '../../shared/models/quote.dart';
import 'quote_repository.dart';

// ---------------------------------------------------------------------------
// HomeState
// ---------------------------------------------------------------------------
class HomeState {
  final AsyncValue<Quote> quote;
  final Set<String> bookmarkedIds;
  final Set<String> likedIds;

  const HomeState({
    required this.quote,
    required this.bookmarkedIds,
    this.likedIds = const {},
  });

  bool isBookmarked(String id) => bookmarkedIds.contains(id);
  bool isLiked(String id) => likedIds.contains(id);

  HomeState copyWith({
    AsyncValue<Quote>? quote,
    Set<String>? bookmarkedIds,
    Set<String>? likedIds,
  }) =>
      HomeState(
        quote: quote ?? this.quote,
        bookmarkedIds: bookmarkedIds ?? this.bookmarkedIds,
        likedIds: likedIds ?? this.likedIds,
      );
}

// ---------------------------------------------------------------------------
// HomeNotifier
// ---------------------------------------------------------------------------
class HomeNotifier extends Notifier<HomeState> {
  int _requestId = 0;
  bool _disposed = false;
  String? _pendingLanguage;
  Future<void>? _pendingQuote;

  @override
  HomeState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _requestId++;
    });
    ref.listen(themeNotifierProvider.select((s) => s.languageCode),
        (previous, next) {
      if (previous != next) loadQuote();
    });
    // 초기화: 명언 로드 + 북마크 + 좋아요 로드
    _init();
    return const HomeState(
      quote: AsyncValue.loading(),
      bookmarkedIds: {},
      likedIds: {},
    );
  }

  QuoteRepository get _repo => ref.read(quoteRepositoryProvider);
  BookmarkRepository get _bookmarkRepo => ref.read(bookmarkRepositoryProvider);
  LikeRepository get _likeRepo => ref.read(likeRepositoryProvider);

  String get _language => ref.read(themeNotifierProvider).languageCode;

  Future<void> _init() async {
    // 북마크 + 좋아요 동시 로드
    final results = await Future.wait([
      _bookmarkRepo.loadBookmarks(),
      _likeRepo.loadLikes(),
    ]);
    if (_disposed) return;
    state = state.copyWith(
      bookmarkedIds: results[0],
      likedIds: results[1],
    );
    // 명언 로드
    if (_requestId == 0) await loadQuote();
  }

  /// 오늘의 명언 로드 (또는 새 명언 불러오기)
  Future<void> loadQuote() {
    final language = _language;
    // 기존 홈 언어 선택기의 명시적 재로딩과 진행 중인 요청을 합친다.
    if (_pendingLanguage == language && _pendingQuote != null) {
      return _pendingQuote!;
    }
    final requestId = ++_requestId;
    _pendingLanguage = language;
    return _pendingQuote = _fetchQuote(language, requestId);
  }

  Future<void> _fetchQuote(String language, int requestId) async {
    state = state.copyWith(quote: const AsyncValue.loading());
    try {
      final quote = await _repo.fetchFeaturedQuote(language: language);
      if (_disposed || requestId != _requestId) return;
      state = state.copyWith(quote: AsyncValue.data(quote));
    } catch (e, st) {
      if (_disposed || requestId != _requestId) return;
      state = state.copyWith(quote: AsyncValue.error(e, st));
    } finally {
      if (requestId == _requestId) {
        _pendingLanguage = null;
        _pendingQuote = null;
      }
    }
  }

  /// 북마크 토글
  Future<void> toggleBookmark(String quoteId) async {
    final current = Set<String>.from(state.bookmarkedIds);
    if (current.contains(quoteId)) {
      current.remove(quoteId);
      await _bookmarkRepo.removeBookmark(quoteId);
    } else {
      current.add(quoteId);
      await _bookmarkRepo.addBookmark(quoteId);
    }
    state = state.copyWith(bookmarkedIds: current);
  }

  /// 좋아요 토글 (낙관적 업데이트)
  Future<void> toggleLike(String quoteId) async {
    final current = Set<String>.from(state.likedIds);
    if (current.contains(quoteId)) {
      current.remove(quoteId);
      await _likeRepo.removeLike(quoteId);
    } else {
      current.add(quoteId);
      await _likeRepo.addLike(quoteId);
    }
    state = state.copyWith(likedIds: current);
  }
}

final homeNotifierProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);
