import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_providers.dart';
import 'community_post.dart';

enum CommunityFailure { registrationRequired, rateLimited, unknown }

class CommunityException implements Exception {
  const CommunityException(this.failure);
  final CommunityFailure failure;

  @override
  String toString() => 'CommunityException($failure)';
}

// ---------------------------------------------------------------------------
// CommunityRepository — Supabase `community_posts` 등을 사용한다.
// 접근 권한과 입력 제한의 최종 책임은 DB의 RLS·제약 조건에 있다.
// ---------------------------------------------------------------------------
class CommunityRepository {
  CommunityRepository(this._client);

  final SupabaseClient _client;

  static const int pageSize = 20;
  static const _select =
      'id, user_id, quote_id, title, content, like_count, created_at, '
      'profiles(display_name, avatar_emoji, avatar_image_data_url)';

  // ── 피드 ────────────────────────────────────────────────────────────────
  /// [after]는 직전 페이지 마지막 글의 `created_at` 원본 문자열이다.
  Future<({List<CommunityPost> posts, String? lastDoc})> fetchPosts({
    String? after,
  }) async {
    var query = _client.from('community_posts').select(_select).eq('hidden', false);
    if (after != null) query = query.lt('created_at', after);
    final rows = await query
        .order('created_at', ascending: false)
        .limit(pageSize);
    return (
      posts: rows.map(CommunityPost.fromRow).toList(),
      lastDoc: rows.isEmpty ? null : rows.last['created_at'] as String,
    );
  }

  // ── 월간 인기 글 ────────────────────────────────────────────────────────
  Future<List<CommunityPost>> fetchTopPosts({int limit = 10}) async {
    final since = DateTime.now().toUtc().subtract(const Duration(days: 30));
    final rows = await _client
        .from('community_posts')
        .select(_select)
        .eq('hidden', false)
        .gt('like_count', 0)
        .gte('created_at', since.toIso8601String())
        .order('like_count', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(CommunityPost.fromRow).toList();
  }

  // ── 글 작성 ─────────────────────────────────────────────────────────────
  /// 작성자는 서버가 로그인 세션(`auth.uid()`)으로 정하며 프로필이 먼저 저장되어 있어야 한다.
  Future<void> createPost({
    required String title,
    required String content,
    String? quoteId,
  }) async {
    final trimmedTitle = title.trim();
    final trimmed = content.trim();
    if (trimmedTitle.isEmpty || trimmedTitle.length > 60) {
      throw ArgumentError('title 길이가 유효하지 않습니다.');
    }
    if (trimmed.length < 2 || trimmed.length > 300) {
      throw ArgumentError('content 길이가 유효하지 않습니다.');
    }
    try {
      await _client.from('community_posts').insert({
        'title': trimmedTitle,
        'content': trimmed,
        if (quoteId != null) 'quote_id': quoteId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const CommunityException(CommunityFailure.registrationRequired);
      }
      if (e.message.contains('post_rate_limit')) {
        throw const CommunityException(CommunityFailure.rateLimited);
      }
      throw const CommunityException(CommunityFailure.unknown);
    }
  }

  Future<void> deletePost(String postId) async {
    await _client.from('community_posts').delete().eq('id', postId);
  }

  Future<void> reportPost(String postId) async {
    try {
      await _client.from('post_reports').insert({'post_id': postId});
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // 이미 신고한 글
    }
  }

  // ── 좋아요 ──────────────────────────────────────────────────────────────
  /// 좋아요 수는 DB 트리거가 갱신하므로 관계 행만 추가/삭제한다.
  Future<void> toggleLike({
    required String postId,
    required String userId,
    required bool currentlyLiked,
  }) async {
    if (currentlyLiked) {
      await _client
          .from('community_post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      return;
    }
    try {
      await _client.from('community_post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // 이미 좋아요한 글
    }
  }

  Future<Set<String>> fetchMyLikes(String userId, List<String> postIds) async {
    if (postIds.isEmpty) return {};
    final rows = await _client
        .from('community_post_likes')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', postIds);
    return rows.map((row) => row['post_id'] as String).toSet();
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(ref.watch(supabaseClientProvider)),
);
