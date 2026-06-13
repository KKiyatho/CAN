import 'package:cloud_firestore/cloud_firestore.dart';

/// 불필요한 공백·줄바꿈을 정규화한다.
/// - 연속 공백/탭/줄바꿈 → 단일 공백
/// - 앞뒤 공백 제거
String _normalize(String text) =>
    text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// 명언 모델
class Quote {
  final String id;
  final String content;
  final String author;
  final String? source;
  final String language;
  final bool isFeatured;
  final List<String> tags;
  final DateTime createdAt;

  const Quote({
    required this.id,
    required this.content,
    required this.author,
    this.source,
    required this.language,
    required this.isFeatured,
    this.tags = const [],
    required this.createdAt,
  });

  factory Quote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Quote(
      id: doc.id,
      content: _normalize(data['content'] as String),
      author: _normalize(data['author'] as String? ?? '미상'),
      source: data['source'] != null
          ? _normalize(data['source'] as String)
          : null,
      language: data['language'] as String? ?? 'ko',
      isFeatured: data['isFeatured'] as bool? ?? false,
      tags: List<String>.from(data['tags'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// 공유 텍스트 형식
  String get shareText =>
      '"$content"\n— $author${source != null ? ' ($source)' : ''}';
}

/// 검색 결과 페이지 (offset 기반 페이지네이션)
class QuotePage {
  final List<Quote> quotes;
  final bool hasMore;
  final int nextOffset;

  const QuotePage({
    required this.quotes,
    required this.hasMore,
    required this.nextOffset,
  });
}
