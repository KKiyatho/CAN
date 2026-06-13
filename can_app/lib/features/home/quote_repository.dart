import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../shared/models/quote.dart';

const _kBookmarksKey = 'bookmarked_quote_ids';
const _kDeviceIdKey = 'device_id';

// ---------------------------------------------------------------------------
// QuoteRepository
// ---------------------------------------------------------------------------
class QuoteRepository {
  final FirebaseFirestore _db;
  QuoteRepository(this._db);

  /// 오늘의 명언: isFeatured=true 중 랜덤 1개
  Future<Quote> fetchFeaturedQuote() async {
    final snapshot = await _db
        .collection('quotes')
        .where('isFeatured', isEqualTo: true)
        .limit(50)
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('명언 데이터가 없습니다. Firestore 시드 데이터를 확인하세요.\n'
          '(firebase/seed_data.js 실행 또는 Firebase 콘솔에서 직접 추가)');
    }

    final koDocs = snapshot.docs
        .map(Quote.fromFirestore)
        .where((q) => q.language == 'ko')
        .toList()
      ..shuffle();

    if (koDocs.isEmpty) {
      throw Exception('한국어 명언 데이터가 없습니다. Firestore 시드 데이터를 확인하세요.');
    }
    return koDocs.first;
  }

  /// 키워드 검색 (클라이언트 사이드 필터링)
  /// Firestore는 LIKE 검색을 지원하지 않아 전체 목록을 받아 필터링합니다.
  Future<QuotePage> searchByKeyword(
    String keyword, {
    int offset = 0,
    int limit = 20,
  }) async {
    final snapshot = await _db
        .collection('quotes')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();

    final normalized = keyword.trim().toLowerCase();
    final all = snapshot.docs
        .map(Quote.fromFirestore)
        .where((q) =>
            q.language == 'ko' &&
            (q.content.toLowerCase().contains(normalized) ||
             q.author.toLowerCase().contains(normalized)))
        .toList();

    final page = all.skip(offset).take(limit).toList();
    return QuotePage(
      quotes: page,
      hasMore: offset + page.length < all.length,
      nextOffset: offset + page.length,
    );
  }

  /// 태그 기반 검색 (Firestore arrayContainsAny)
  Future<QuotePage> searchByTags(
    List<String> tags, {
    int offset = 0,
    int limit = 20,
  }) async {
    if (tags.isEmpty) {
      return const QuotePage(quotes: [], hasMore: false, nextOffset: 0);
    }

    // arrayContainsAny 최대 10개
    final effectiveTags = tags.take(10).toList();
    final snapshot = await _db
        .collection('quotes')
        .where('tags', arrayContainsAny: effectiveTags)
        .limit(100)
        .get();

    final all = snapshot.docs
        .map(Quote.fromFirestore)
        .where((q) => q.language == 'ko')
        .toList();
    final page = all.skip(offset).take(limit).toList();
    return QuotePage(
      quotes: page,
      hasMore: offset + page.length < all.length,
      nextOffset: offset + page.length,
    );
  }

  // -------------------------------------------------------------------------
  // 카테고리 상세용 커서 기반 페이지네이션 (startAfterDocument)
  // -------------------------------------------------------------------------
  /// [tag] 에 해당하는 명언을 [limit]개씩 가져온다.
  /// [lastDoc]이 있으면 그 문서 이후부터 이어서 가져온다 (다음 페이지).
  ///
  /// Firestore arrayContains + 커서 기반 → composite index 불필요.
  /// language 필터는 클라이언트 사이드에서 처리한다.
  Future<TagPageResult> fetchByTagPaginated(
    String tag, {
    DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('quotes')
        .where('tags', arrayContains: tag)
        .limit(limit * 2); // 언어 필터 손실 보정

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;

    final quotes = docs
        .map(Quote.fromFirestore)
        .where((q) => q.language == 'ko')
        .take(limit)
        .toList();

    return TagPageResult(
      quotes: quotes,
      lastDoc: docs.isNotEmpty ? docs.last : null,
      hasMore: docs.length >= limit,
    );
  }
}

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => QuoteRepository(ref.watch(firestoreProvider)),
);

// ---------------------------------------------------------------------------
// TagPageResult (커서 기반 페이지네이션 결과)
// ---------------------------------------------------------------------------
class TagPageResult {
  final List<Quote> quotes;

  /// 다음 페이지 커서 (마지막 문서 스냅샷)
  final DocumentSnapshot? lastDoc;

  /// 더 불러올 데이터가 있는지 여부
  final bool hasMore;

  const TagPageResult({
    required this.quotes,
    this.lastDoc,
    required this.hasMore,
  });
}

// ---------------------------------------------------------------------------
// BookmarkRepository (로컬 SharedPreferences)
// ---------------------------------------------------------------------------
class BookmarkRepository {
  Future<Set<String>> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kBookmarksKey) ?? []).toSet();
  }

  Future<void> addBookmark(String quoteId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kBookmarksKey) ?? [];
    if (!raw.contains(quoteId)) {
      raw.add(quoteId);
      await prefs.setStringList(_kBookmarksKey, raw);
    }
  }

  Future<void> removeBookmark(String quoteId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kBookmarksKey) ?? [];
    raw.remove(quoteId);
    await prefs.setStringList(_kBookmarksKey, raw);
  }

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_kDeviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_kDeviceIdKey, id);
    }
    return id;
  }
}

final bookmarkRepositoryProvider = Provider<BookmarkRepository>(
  (_) => BookmarkRepository(),
);
