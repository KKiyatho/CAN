import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/quote.dart';
import 'quote_repository.dart';

// ---------------------------------------------------------------------------
// HomeState
// ---------------------------------------------------------------------------
class HomeState {
  final AsyncValue<Quote> quote;
  final Set<String> bookmarkedIds;

  const HomeState({
    required this.quote,
    required this.bookmarkedIds,
  });

  bool isBookmarked(String id) => bookmarkedIds.contains(id);

  HomeState copyWith({
    AsyncValue<Quote>? quote,
    Set<String>? bookmarkedIds,
  }) =>
      HomeState(
        quote: quote ?? this.quote,
        bookmarkedIds: bookmarkedIds ?? this.bookmarkedIds,
      );
}

// ---------------------------------------------------------------------------
// HomeNotifier
// ---------------------------------------------------------------------------
class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    // 초기화: 명언 로드 + 북마크 목록 로드
    _init();
    return const HomeState(
      quote: AsyncValue.loading(),
      bookmarkedIds: {},
    );
  }

  QuoteRepository get _repo => ref.read(quoteRepositoryProvider);
  BookmarkRepository get _bookmarkRepo => ref.read(bookmarkRepositoryProvider);

  Future<void> _init() async {
    // 북마크 먼저 로드
    final ids = await _bookmarkRepo.loadBookmarks();
    state = state.copyWith(bookmarkedIds: ids);
    // 명언 로드
    await loadQuote();
  }

  /// 오늘의 명언 로드 (또는 새 명언 불러오기)
  Future<void> loadQuote() async {
    state = state.copyWith(quote: const AsyncValue.loading());
    try {
      final quote = await _repo.fetchFeaturedQuote();
      state = state.copyWith(quote: AsyncValue.data(quote));
    } catch (e, st) {
      state = state.copyWith(quote: AsyncValue.error(e, st));
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
}

final homeNotifierProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);
