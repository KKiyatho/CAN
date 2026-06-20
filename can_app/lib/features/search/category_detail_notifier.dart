import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/i18n.dart';
import '../../core/theme/theme_notifier.dart';
import '../../shared/models/quote.dart';
import '../home/quote_repository.dart';

// ---------------------------------------------------------------------------
// 카테고리 상세 상태
// ---------------------------------------------------------------------------
class CategoryDetailState {
  final List<Quote> quotes;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int nextOffset;
  final String? error;

  const CategoryDetailState({
    this.quotes = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.nextOffset = 0,
    this.error,
  });

  CategoryDetailState copyWith({
    List<Quote>? quotes,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? nextOffset,
    String? error,
    bool clearError = false,
  }) =>
      CategoryDetailState(
        quotes: quotes ?? this.quotes,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        nextOffset: nextOffset ?? this.nextOffset,
        error: clearError ? null : error ?? this.error,
      );
}

// ---------------------------------------------------------------------------
// CategoryDetailNotifier — tag 별로 독립 상태 (autoDispose.family)
// fetchByTagPaginated() cursor 방식 사용 (startAfterDocument)
// ---------------------------------------------------------------------------
class CategoryDetailNotifier
    extends AutoDisposeFamilyNotifier<CategoryDetailState, String> {
  static const int _pageSize = 50;

  @override
  CategoryDetailState build(String tag) {
    final link = ref.keepAlive();
    Future.microtask(() async {
      await _loadInitial(tag);
      link.close();
    });
    return const CategoryDetailState(isLoading: true);
  }

  // ── 첫 페이지 로딩 ─────────────────────────────────────────────────────
  Future<void> _loadInitial(String tag) async {
    final repo = ref.read(quoteRepositoryProvider);
    final language = ref.read(themeNotifierProvider).languageCode;

    // 1. 로컬 캐시 먼저 표시 (빠른 첫 렌더링)
    final cached = await _loadCache(tag, language);
    if (cached != null && cached.isNotEmpty) {
      state = state.copyWith(
        quotes: cached,
        isLoading: false,
        hasMore: true,
        clearError: true,
      );
    }

    // 2. Firestore에서 최신 첫 페이지 가져오기 (cursor 없이)
    try {
      final result = await repo.fetchByTagPaginated(tag,
          limit: _pageSize, language: language);

      await _saveCache(tag, language, result.quotes);

      state = state.copyWith(
        quotes: result.quotes,
        isLoading: false,
        hasMore: result.hasMore,
        nextOffset: result.nextOffset,
        clearError: true,
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('[CategoryDetail] 로딩 실패 (tag=$tag): $e\n$st');
      final lang = ref.read(themeNotifierProvider).languageCode;
      state = state.copyWith(
        isLoading: false,
        error: state.quotes.isEmpty
            ? '${I18n.t(lang, 'category.loadError')}\n($e)'
            : null,
      );
    }
  }

  // ── 다음 페이지 (무한 스크롤) ──────────────────────────────────────────
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    final repo = ref.read(quoteRepositoryProvider);
    final language = ref.read(themeNotifierProvider).languageCode;
    try {
      final result = await repo.fetchByTagPaginated(
        arg,
        offset: state.nextOffset,
        limit: _pageSize,
        language: language,
      );

      state = state.copyWith(
        quotes: [...state.quotes, ...result.quotes],
        isLoadingMore: false,
        hasMore: result.hasMore,
        nextOffset: result.nextOffset,
        clearError: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[CategoryDetail] loadMore 실패: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // ── 재시도 ─────────────────────────────────────────────────────────────
  Future<void> retry() async {
    state = const CategoryDetailState(isLoading: true);
    await _loadInitial(arg);
  }

  // ── 로컬 캐시 (SharedPreferences) ─────────────────────────────────────
  static String _cacheKey(String tag, String language) =>
      'quote_cache_tag_${language}_$tag';

  Future<List<Quote>?> _loadCache(String tag, String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(tag, language));
      if (raw == null) return null;
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Quote.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(String tag, String language, List<Quote> quotes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(quotes.map((q) => q.toMap()).toList());
      await prefs.setString(_cacheKey(tag, language), encoded);
    } catch (_) {
      // 캐시 저장 실패는 무시
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final categoryDetailProvider = NotifierProvider.autoDispose
    .family<CategoryDetailNotifier, CategoryDetailState, String>(
  CategoryDetailNotifier.new,
);
