import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// CommunityPost 모델
// ---------------------------------------------------------------------------
class CommunityPost {
  final String id;
  final String userId;
  final String? quoteId;
  final String title;
  final String content;
  final int likeCount;
  final bool likedByMe; // 클라이언트 전용 (낙관적 업데이트용)
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.userId,
    this.quoteId,
    required this.title,
    required this.content,
    required this.likeCount,
    this.likedByMe = false,
    required this.createdAt,
  });

  factory CommunityPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityPost(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      quoteId: data['quoteId'] as String?,
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
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
        quoteId: quoteId,
        title: title,
        content: content,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        createdAt: createdAt,
      );
}
