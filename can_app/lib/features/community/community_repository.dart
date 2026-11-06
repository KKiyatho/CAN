import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'community_post.dart';

// ---------------------------------------------------------------------------
// CommunityRepository
// ---------------------------------------------------------------------------
class CommunityRepository {
  static final List<CommunityPost> _inMemoryPosts = <CommunityPost>[];
  static final Map<String, Set<String>> _likedByPost = <String, Set<String>>{};

  CommunityRepository();

  static const int pageSize = 20;

  // ── 피드 첫 페이지 ──────────────────────────────────────────────────────
  Future<({List<CommunityPost> posts, String? lastDoc})> fetchPosts({String? after}) async {
    final items = [..._inMemoryPosts];
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final startIndex = after == null
        ? 0
        : (() {
            final index = items.indexWhere((post) => post.id == after);
            return index == -1 ? 0 : index + 1;
          })();

    final page = items.skip(startIndex).take(pageSize).toList();
    return (
      posts: page,
      lastDoc: page.isNotEmpty ? page.last.id : null,
    );
  }

  // ── 인기 글 (likeCount 상위 10개) ────────────────────────────────────────
  Future<List<CommunityPost>> fetchTopPosts({int limit = 10}) async {
    final items = [..._inMemoryPosts];
    items.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    return items.take(limit).toList();
  }

  // ── 글 작성 ────────────────────────────────────────────────────────────
  Future<void> createPost({
    required String userId,
    required String displayName,
    required String avatarEmoji,
    String? avatarImageDataUrl,
    required String title,
    required String content,
    String? quoteId,
  }) async {
    final trimmedTitle = title.trim();
    final trimmed = content.trim();
    if (trimmedTitle.isEmpty || trimmedTitle.length > 60) {
      throw ArgumentError('title 길이가 유효하지 않습니다.');
    }
    if (trimmed.isEmpty || trimmed.length < 2 || trimmed.length > 300) {
      throw ArgumentError('content 길이가 유효하지 않습니다.');
    }
    if (userId.isEmpty) throw ArgumentError('userId가 유효하지 않습니다.');

    final post = CommunityPost(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      userId: userId,
      displayName: displayName.trim().isEmpty ? 'Guest' : displayName.trim(),
      avatarEmoji: avatarEmoji.trim().isEmpty ? '🐣' : avatarEmoji.trim(),
      avatarImageDataUrl: avatarImageDataUrl,
      quoteId: quoteId,
      title: trimmedTitle,
      content: trimmed,
      likeCount: 0,
      createdAt: DateTime.now(),
    );

    _inMemoryPosts.insert(0, post);
  }

  // ── 하트 토글 ──────────────────────────────────────────────────────────
  Future<void> toggleLike({
    required String postId,
    required String userId,
    required bool currentlyLiked,
  }) async {
    final index = _inMemoryPosts.indexWhere((post) => post.id == postId);
    if (index == -1) return;

    final existing = _inMemoryPosts[index];
    final nextLikeCount = currentlyLiked ? existing.likeCount - 1 : existing.likeCount + 1;
    final next = existing.copyWith(
      likeCount: nextLikeCount < 0 ? 0 : nextLikeCount,
      likedByMe: !currentlyLiked,
    );

    _inMemoryPosts[index] = next;
    final members = _likedByPost.putIfAbsent(postId, () => <String>{});
    if (currentlyLiked) {
      members.remove(userId);
    } else {
      members.add(userId);
    }
  }

  // ── 내가 좋아요 한 글 ID 목록 ─────────────────────────────────────────
  Future<Set<String>> fetchMyLikes(String userId, List<String> postIds) async {
    if (postIds.isEmpty) return {};
    final result = <String>{};
    for (final postId in postIds) {
      final likedUsers = _likedByPost[postId] ?? const <String>{};
      if (likedUsers.contains(userId)) {
        result.add(postId);
      }
    }
    return result;
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>(
  (_) => CommunityRepository(),
);
