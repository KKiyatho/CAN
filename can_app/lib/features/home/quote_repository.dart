import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../shared/models/quote.dart';

const _kBookmarksKey = 'bookmarked_quote_ids';
const _kLikesKey = 'liked_quote_ids';
const _kDeviceIdKey = 'device_id';

// ---------------------------------------------------------------------------
// QuoteRepository
// ---------------------------------------------------------------------------
class QuoteRepository {
  final FirebaseFirestore _db;
  QuoteRepository(this._db);

  /// 오늘의 명언: isFeatured=true 중 랜덤 1개
  /// [language]: 'ko' | 'en' | 'all'
  Future<Quote> fetchFeaturedQuote({String language = 'ko'}) async {
    final snapshot = await _db
        .collection('quotes')
        .where('isFeatured', isEqualTo: true)
        .limit(50)
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('명언 데이터가 없습니다. Firestore 시드 데이터를 확인하세요.\n'
          '(firebase/seed_data.js 실행 또는 Firebase 콘솔에서 직접 추가)');
    }

    final filtered = snapshot.docs
        .map(Quote.fromFirestore)
        .where((q) => language == 'all' || q.language == language)
        .toList()
      ..shuffle();

    if (filtered.isEmpty) {
      // 선택 언어 데이터 없으면 전체에서 랜덤
      final all = snapshot.docs.map(Quote.fromFirestore).toList()..shuffle();
      return all.first;
    }
    return filtered.first;
  }

  /// 키워드 검색 (클라이언트 사이드 필터링)
  /// Firestore는 LIKE 검색을 지원하지 않아 전체 목록을 받아 필터링합니다.
  Future<QuotePage> searchByKeyword(
    String keyword, {
    int offset = 0,
    int limit = 20,
    String language = 'ko',
  }) async {
    final snapshot = await _db
        .collection('quotes')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .get();

    final normalized = keyword.trim().toLowerCase();
    final all = snapshot.docs
        .map(Quote.fromFirestore)
        .where((q) =>
            (language == 'all' || q.language == language) &&
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
    String language = 'ko',
  }) async {
    if (tags.isEmpty) {
      return const QuotePage(quotes: [], hasMore: false, nextOffset: 0);
    }

    // arrayContainsAny 최대 10개
    final effectiveTags = tags.take(10).toList();
    final snapshot = await _db
        .collection('quotes')
        .where('tags', arrayContainsAny: effectiveTags)
        .limit(500)
        .get();

    final all = snapshot.docs
        .map(Quote.fromFirestore)
        .where((q) => language == 'all' || q.language == language)
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
    String language = 'ko',
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
        .where((q) => language == 'all' || q.language == language)
        .take(limit)
        .toList();

    return TagPageResult(
      quotes: quotes,
      lastDoc: docs.isNotEmpty ? docs.last : null,
      // Firestore 가 limit*2 개를 반환했으면 더 있을 수 있음
      hasMore: docs.length >= limit * 2,
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
      id = _generateId();
      await prefs.setString(_kDeviceIdKey, id);
    }
    return id;
  }

  static String _generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}'
        '-${hex.substring(12, 16)}-${hex.substring(16, 20)}'
        '-${hex.substring(20, 32)}';
  }
}

final bookmarkRepositoryProvider = Provider<BookmarkRepository>(
  (_) => BookmarkRepository(),
);

// ---------------------------------------------------------------------------
// LikeRepository (로컬 SharedPreferences — 명언 좋아요)
// ---------------------------------------------------------------------------
class LikeRepository {
  Future<Set<String>> loadLikes() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kLikesKey) ?? []).toSet();
  }

  Future<void> addLike(String quoteId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kLikesKey) ?? [];
    if (!raw.contains(quoteId)) {
      raw.add(quoteId);
      await prefs.setStringList(_kLikesKey, raw);
    }
  }

  Future<void> removeLike(String quoteId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kLikesKey) ?? [];
    raw.remove(quoteId);
    await prefs.setStringList(_kLikesKey, raw);
  }
}

final likeRepositoryProvider = Provider<LikeRepository>(
  (_) => LikeRepository(),
);
