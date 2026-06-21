import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/auth_providers.dart';
import '../../core/theme/i18n.dart';
import '../../core/theme/theme_notifier.dart';
import 'community_post.dart';
import 'community_repository.dart';

// ---------------------------------------------------------------------------
// 커뮤니티 피드 상태
// ---------------------------------------------------------------------------
class CommunityState {
  final List<CommunityPost> posts;
  final List<CommunityPost> topPosts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final DocumentSnapshot? lastDoc;
  final String? error;

  const CommunityState({
    this.posts = const [],
    this.topPosts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastDoc,
    this.error,
  });

  CommunityState copyWith({
    List<CommunityPost>? posts,
    List<CommunityPost>? topPosts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    DocumentSnapshot? lastDoc,
    bool setLastDoc = false,
    String? error,
    bool clearError = false,
  }) =>
      CommunityState(
        posts: posts ?? this.posts,
        topPosts: topPosts ?? this.topPosts,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        lastDoc: setLastDoc ? lastDoc : this.lastDoc,
        error: clearError ? null : error ?? this.error,
      );
}

// ---------------------------------------------------------------------------
// CommunityNotifier
// ---------------------------------------------------------------------------
class CommunityNotifier extends Notifier<CommunityState> {
  @override
  CommunityState build() {
    Future.microtask(() => _loadInitial());
    return const CommunityState(isLoading: true);
  }

  // ── 첫 페이지 + 인기 글 동시 로딩 ──────────────────────────────────────
  Future<void> _loadInitial() async {
    final repo = ref.read(communityRepositoryProvider);
    try {
      final auth = ref.read(firebaseAuthProvider);
      await signInAnonymouslyIfNeeded(auth);

      final results = await Future.wait([
        repo.fetchPosts(),
        repo.fetchTopPosts(),
      ]);

      final feedResult = results[0]
          as ({List<CommunityPost> posts, DocumentSnapshot? lastDoc});
      final topPosts = results[1] as List<CommunityPost>;

      // 좋아요 여부 조회
      final userId = ref.read(currentUserIdProvider);
      final withLikes = await _applyLikes(feedResult.posts, userId);

      state = state.copyWith(
        posts: withLikes,
        topPosts: topPosts,
        isLoading: false,
        hasMore: feedResult.posts.length >= CommunityRepository.pageSize,
        lastDoc: feedResult.lastDoc,
        setLastDoc: true,
        clearError: true,
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Community] 로딩 실패: $e\n$st');
      final lang = ref.read(themeNotifierProvider).languageCode;
      state = state.copyWith(
        isLoading: false,
        error: I18n.t(lang, 'community.loadError'),
      );
    }
  }

  // ── 더 불러오기 (무한 스크롤) ────────────────────────────────────────────
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);

    final repo = ref.read(communityRepositoryProvider);
    try {
      final result = await repo.fetchPosts(after: state.lastDoc);
      final userId = ref.read(currentUserIdProvider);
      final withLikes = await _applyLikes(result.posts, userId);

      state = state.copyWith(
        posts: [...state.posts, ...withLikes],
        isLoadingMore: false,
        hasMore: result.posts.length >= CommunityRepository.pageSize,
        lastDoc: result.lastDoc,
        setLastDoc: true,
        clearError: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Community] loadMore 실패: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // ── 하트 낙관적 업데이트 ────────────────────────────────────────────────
  Future<void> toggleLike(String postId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = state.posts[idx];
    final nowLiked = !post.likedByMe;
    final delta = nowLiked ? 1 : -1;

    // 낙관적 업데이트
    final updated = List<CommunityPost>.from(state.posts);
    updated[idx] = post.copyWith(
      likeCount: post.likeCount + delta,
      likedByMe: nowLiked,
    );
    state = state.copyWith(posts: updated);

    try {
      await ref.read(communityRepositoryProvider).toggleLike(
            postId: postId,
            userId: userId,
            currentlyLiked: post.likedByMe,
          );
    } catch (e) {
      // 실패 시 롤백
      if (kDebugMode) debugPrint('[Community] toggleLike 실패: $e');
      final rollback = List<CommunityPost>.from(state.posts);
      rollback[idx] = post;
      state = state.copyWith(posts: rollback);
    }
  }

  // ── 글 작성 후 피드 새로고침 ─────────────────────────────────────────────
  Future<void> refresh() async {
    state = const CommunityState(isLoading: true);
    await _loadInitial();
  }

  // ── 좋아요 여부를 posts에 반영 ────────────────────────────────────────────
  Future<List<CommunityPost>> _applyLikes(
    List<CommunityPost> posts,
    String? userId,
  ) async {
    if (userId == null || posts.isEmpty) return posts;
    try {
      final likedIds = await ref
          .read(communityRepositoryProvider)
          .fetchMyLikes(userId, posts.map((p) => p.id).toList());
      return posts
          .map((p) => p.copyWith(likedByMe: likedIds.contains(p.id)))
          .toList();
    } catch (_) {
      return posts;
    }
  }
}

final communityNotifierProvider =
    NotifierProvider<CommunityNotifier, CommunityState>(CommunityNotifier.new);
