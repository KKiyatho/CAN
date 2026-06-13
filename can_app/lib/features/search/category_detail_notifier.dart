import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final int nextOffset;   // 다음 페이지 offset
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
// 기존에 작동이 확인된 searchByTags() 방식을 재사용한다.
// ---------------------------------------------------------------------------
class CategoryDetailNotifier
    extends AutoDisposeFamilyNotifier<CategoryDetailState, String> {
  static const int _pageSize = 20;

  @override
  CategoryDetailState build(String tag) {
    // autoDispose 중에도 진행 중인 fetch가 유효하게 유지되도록 keepAlive 설정
    final link = ref.keepAlive();
    // 첫 페이지 로딩 완료 후 keepAlive 해제
    Future.microtask(() async {
      await _loadInitial(tag);
      link.close();
    });
    return const CategoryDetailState(isLoading: true);
  }

  // ── 첫 페이지 로딩 ─────────────────────────────────────────────────────
  Future<void> _loadInitial(String tag) async {
    // ref 사용 전에 미리 읽어둔다 (await 이후 ref 접근 방지)
    final repo = ref.read(quoteRepositoryProvider);

    // 1. 로컬 캐시 먼저 표시 (빠른 첫 렌더링)
    final cached = await _loadCache(tag);
    if (cached != null && cached.isNotEmpty) {
      state = state.copyWith(
        quotes: cached,
        isLoading: false,
        hasMore: true,
        clearError: true,
      );
    }

    // 2. Firestore에서 최신 첫 페이지 가져오기
    // searchByTags는 기존 검색 탭에서도 사용하는 검증된 메서드
    try {
      final page = await repo.searchByTags(
        [tag],
        offset: 0,
        limit: _pageSize,
      );

      await _saveCache(tag, page.quotes);

      state = state.copyWith(
        quotes: page.quotes,
        isLoading: false,
        hasMore: page.hasMore,
        nextOffset: page.nextOffset,
        clearError: true,
      );
    } catch (e, st) {
      debugPrint('[CategoryDetail] 로딩 실패 (tag=$tag): $e\n$st');
      state = state.copyWith(
        isLoading: false,
        error: state.quotes.isEmpty
            ? '명언을 불러오지 못했습니다.\n($e)'
            : null,
      );
    }
  }

  // ── 다음 페이지 (무한 스크롤) ──────────────────────────────────────────
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    final repo = ref.read(quoteRepositoryProvider);
    try {
      final page = await repo.searchByTags(
        [arg],
        offset: state.nextOffset,
        limit: _pageSize,
      );

      state = state.copyWith(
        quotes: [...state.quotes, ...page.quotes],
        isLoadingMore: false,
        hasMore: page.hasMore,
        nextOffset: page.nextOffset,
        clearError: true,
      );
    } catch (e) {
      debugPrint('[CategoryDetail] loadMore 실패: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // ── 재시도 ─────────────────────────────────────────────────────────────
  Future<void> retry() async {
    state = const CategoryDetailState(isLoading: true);
    await _loadInitial(arg);
  }

  // ── 로컬 캐시 (SharedPreferences) ─────────────────────────────────────
  static String _cacheKey(String tag) => 'quote_cache_tag_$tag';

  Future<List<Quote>?> _loadCache(String tag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(tag));
      if (raw == null) return null;
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Quote.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(String tag, List<Quote> quotes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(quotes.map((q) => q.toMap()).toList());
      await prefs.setString(_cacheKey(tag), encoded);
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
