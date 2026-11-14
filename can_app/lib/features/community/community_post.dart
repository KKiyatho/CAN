// ---------------------------------------------------------------------------
// CommunityPost 모델
// ---------------------------------------------------------------------------
class CommunityPost {
  final String id;
  final String userId;
  final String displayName;
  final String avatarEmoji;
  final String? avatarImageDataUrl;
  final String? quoteId;
  final String title;
  final String content;
  final int likeCount;
  final bool likedByMe; // 클라이언트 전용 (낙관적 업데이트용)
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.avatarEmoji,
    this.avatarImageDataUrl,
    this.quoteId,
    required this.title,
    required this.content,
    required this.likeCount,
    this.likedByMe = false,
    required this.createdAt,
  });

  /// `community_posts` 행(+ 임베드된 `profiles`)을 모델로 변환한다.
  factory CommunityPost.fromRow(Map<String, dynamic> row) {
    final profile = row['profiles'];
    final profileMap = profile is Map<String, dynamic> ? profile : const {};
    final name = (profileMap['display_name'] as String? ?? '').trim();
    final emoji = (profileMap['avatar_emoji'] as String? ?? '').trim();
    final image = (profileMap['avatar_image_data_url'] as String?)?.trim();
    return CommunityPost(
      id: row['id'] as String,
      userId: row['user_id'] as String? ?? '',
      displayName: name.isEmpty ? 'Guest' : name,
      avatarEmoji: emoji.isEmpty ? '🐣' : emoji,
      avatarImageDataUrl: image == null || image.isEmpty ? null : image,
      quoteId: row['quote_id'] as String?,
      title: (row['title'] as String? ?? '').trim(),
      content: (row['content'] as String? ?? '').trim(),
      likeCount: (row['like_count'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  CommunityPost copyWith({int? likeCount, bool? likedByMe}) => CommunityPost(
    id: id,
    userId: userId,
    displayName: displayName,
    avatarEmoji: avatarEmoji,
    avatarImageDataUrl: avatarImageDataUrl,
    quoteId: quoteId,
    title: title,
    content: content,
    likeCount: likeCount ?? this.likeCount,
    likedByMe: likedByMe ?? this.likedByMe,
    createdAt: createdAt,
  );
}
