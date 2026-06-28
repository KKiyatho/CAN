import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import 'community_post.dart';

// ---------------------------------------------------------------------------
// CommunityRepository
// ---------------------------------------------------------------------------
class CommunityRepository {
  final FirebaseFirestore _db;
  CommunityRepository(this._db);

  static const _postsCol = 'community_posts';
  static const _likesCol = 'post_likes';
  static const int pageSize = 20;

  // ── 피드 첫 페이지 ──────────────────────────────────────────────────────
  Future<({List<CommunityPost> posts, DocumentSnapshot? lastDoc})>
      fetchPosts({DocumentSnapshot? after}) async {
    Query<Map<String, dynamic>> q = _db
        .collection(_postsCol)
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (after != null) q = q.startAfterDocument(after);

    final snap = await q.get();
    final posts = snap.docs.map(CommunityPost.fromFirestore).toList();
    return (
      posts: posts,
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  // ── 인기 글 (likeCount 상위 10개) ────────────────────────────────────────
  Future<List<CommunityPost>> fetchTopPosts({int limit = 10}) async {
    final snap = await _db
        .collection(_postsCol)
        .orderBy('likeCount', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(CommunityPost.fromFirestore).toList();
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
    // 서버측 검증 (Firestore Rules 와 이중 방어)
    final trimmedTitle = title.trim();
    final trimmed = content.trim();
    if (trimmedTitle.isEmpty || trimmedTitle.length > 60) {
      throw ArgumentError('title 길이가 유효하지 않습니다.');
    }
    if (trimmed.isEmpty || trimmed.length < 2 || trimmed.length > 300) {
      throw ArgumentError('content 길이가 유효하지 않습니다.');
    }
    if (userId.isEmpty) throw ArgumentError('userId가 유효하지 않습니다.');

    await _db.collection(_postsCol).add({
        'userId': userId,
        'displayName': displayName.trim().isEmpty ? 'Guest' : displayName.trim(),
        'avatarEmoji': avatarEmoji.trim().isEmpty ? '🐣' : avatarEmoji.trim(),
        if (avatarImageDataUrl != null && avatarImageDataUrl.isNotEmpty)
          'avatarImageDataUrl': avatarImageDataUrl,
        if (quoteId != null) 'quoteId': quoteId,
        'title': trimmedTitle,
        'content': trimmed,
        'likeCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
  }

  // ── 하트 토글 ──────────────────────────────────────────────────────────
  /// 좋아요 여부를 확인하고 토글. [likedByMe] 현재 상태를 받아 반전.
  Future<void> toggleLike({
    required String postId,
    required String userId,
    required bool currentlyLiked,
  }) async {
    final likeRef = _db
        .collection(_postsCol)
        .doc(postId)
        .collection(_likesCol)
        .doc(userId);
    final postRef = _db.collection(_postsCol).doc(postId);

    final batch = _db.batch();
    if (currentlyLiked) {
      batch.delete(likeRef);
      batch.update(postRef, {'likeCount': FieldValue.increment(-1)});
    } else {
      batch.set(likeRef, {'userId': userId, 'createdAt': FieldValue.serverTimestamp()});
      batch.update(postRef, {'likeCount': FieldValue.increment(1)});
    }
    await batch.commit();
  }

  // ── 내가 좋아요 한 글 ID 목록 ─────────────────────────────────────────
  Future<Set<String>> fetchMyLikes(String userId, List<String> postIds) async {
    if (postIds.isEmpty) return {};
    final futures = postIds.map((pid) => _db
        .collection(_postsCol)
        .doc(pid)
        .collection(_likesCol)
        .doc(userId)
        .get());
    final results = await Future.wait(futures);
    return {
      for (int i = 0; i < postIds.length; i++)
        if (results[i].exists) postIds[i],
    };
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(ref.watch(firestoreProvider)),
);
