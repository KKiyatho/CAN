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
}

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => QuoteRepository(ref.watch(firestoreProvider)),
);

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
