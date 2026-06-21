import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory CommunityPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawContent = data['content'] as String? ?? '';
    final rawTitle = data['title'] as String?;

    String resolvedTitle = rawTitle?.trim() ?? '';
    String resolvedContent = rawContent;

    if (resolvedTitle.isEmpty && rawContent.startsWith('[')) {
      final splitAt = rawContent.indexOf(']\n');
      if (splitAt > 1) {
        resolvedTitle = rawContent.substring(1, splitAt).trim();
        resolvedContent = rawContent.substring(splitAt + 2).trim();
      }
    }

    return CommunityPost(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      displayName: (data['displayName'] as String? ?? 'Guest').trim(),
      avatarEmoji: (data['avatarEmoji'] as String? ?? '🐣').trim().isEmpty
          ? '🐣'
          : (data['avatarEmoji'] as String? ?? '🐣').trim(),
      avatarImageDataUrl: (data['avatarImageDataUrl'] as String?)?.trim(),
      quoteId: data['quoteId'] as String?,
      title: resolvedTitle,
      content: resolvedContent,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'displayName': displayName,
        'avatarEmoji': avatarEmoji,
        if (avatarImageDataUrl != null) 'avatarImageDataUrl': avatarImageDataUrl,
        if (quoteId != null) 'quoteId': quoteId,
      'title': title,
        'content': content,
        'likeCount': likeCount,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  CommunityPost copyWith({
    int? likeCount,
    bool? likedByMe,
  }) =>
      CommunityPost(
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
