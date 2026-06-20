import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
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

  static List<Quote>? _localQuotesCache;
  static List<Quote>? _firestoreQuotesCache;
  static DateTime? _firestoreQuotesLoadedAt;
  static const _firestoreCacheTtl = Duration(minutes: 10);

  static const Map<String, List<String>> _tagToLocalTokens = {
    '불안': ['anxiety', 'fear', 'worry', 'stress', 'sadness'],
    '지침': ['motivation', 'inspirational', 'life', 'hope', 'strength'],
    '면접': ['work', 'success', 'achievement', 'career'],
    '관계': ['friendship', 'love', 'relationship'],
    '철학': ['philosophy', 'truth', 'wisdom'],
    '성공': ['success', 'achievement', 'work'],
    '독서': ['books', 'reading', 'literature'],
    '지혜': ['wisdom', 'knowledge', 'science', 'truth'],
    '창의력': ['art', 'creativity', 'imagination'],
    '도전': ['motivational', 'inspirational', 'courage', 'strength'],
    '용기': ['courage', 'strength', 'bravery'],
    '믿음': ['faith', 'hope', 'religion'],
    '사랑': ['love', 'romance'],
    '행복': ['happiness', 'joy', 'smile'],
    '자기계발': ['inspirational', 'motivational', 'self', 'growth'],
    '삶': ['life', 'living'],
  };

  static List<Quote> _builtinFallbackQuotes() {
    final now = DateTime(2020, 1, 1);
    return [
      Quote(
        id: 'builtin_1',
        content: 'You do not have to be fearless. You only have to move forward.',
        author: 'CAN',
        source: null,
        language: 'en',
        isFeatured: false,
        tags: const ['courage', 'strength', 'motivation', '도전', '용기'],
        createdAt: now,
      ),
      Quote(
        id: 'builtin_2',
        content: '작은 한 걸음이 불안을 이기는 가장 빠른 방법이다.',
        author: 'CAN',
        source: null,
        language: 'ko',
        isFeatured: false,
        tags: const ['불안', '용기', '삶'],
        createdAt: now.add(const Duration(seconds: 1)),
      ),
      Quote(
        id: 'builtin_3',
        content: 'Rest if you must, but do not quit.',
        author: 'Unknown',
        source: null,
        language: 'en',
        isFeatured: false,
        tags: const ['motivation', 'growth', '지침', '자기계발'],
        createdAt: now.add(const Duration(seconds: 2)),
      ),
      Quote(
        id: 'builtin_4',
        content: '관계는 정답이 아니라, 서로를 이해하려는 연습이다.',
        author: 'CAN',
        source: null,
        language: 'ko',
        isFeatured: false,
        tags: const ['관계', '사랑', '행복'],
        createdAt: now.add(const Duration(seconds: 3)),
      ),
      Quote(
        id: 'builtin_5',
        content: 'Success is built from ordinary days done consistently.',
        author: 'CAN',
        source: null,
        language: 'en',
        isFeatured: false,
        tags: const ['success', 'work', '성공', '자기계발'],
        createdAt: now.add(const Duration(seconds: 4)),
      ),
      Quote(
        id: 'builtin_6',
        content: '오늘의 평온은 어제의 걱정을 조금 내려놓은 결과다.',
        author: 'CAN',
        source: null,
        language: 'ko',
        isFeatured: false,
        tags: const ['행복', '삶', '믿음'],
        createdAt: now.add(const Duration(seconds: 5)),
      ),
    ];
  }

  Future<List<Quote>> _loadLocalQuotes() async {
    if (_localQuotesCache != null) return _localQuotesCache!;
    try {
      final raw = await rootBundle.loadString('assets/quotes.json');
      final decodedAny = jsonDecode(raw);
      final decoded = decodedAny is List<dynamic>
          ? decodedAny
          : (decodedAny is Map<String, dynamic>
              ? (decodedAny['quotes'] as List<dynamic>? ?? const [])
              : const <dynamic>[]);

      final parsed = <Quote>[];
      for (var i = 0; i < decoded.length; i++) {
        final item = decoded[i] as Map<String, dynamic>;
        final content = (item['Quote'] as String? ?? '').trim();
        if (content.isEmpty) continue;
        final author = (item['Author'] as String? ?? 'Unknown').trim();
        final category =
            (item['Category'] as String? ?? '').trim().toLowerCase();
        final tagsRaw = (item['Tags'] as List<dynamic>? ?? [])
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList();
        final mergedTags = {...tagsRaw, if (category.isNotEmpty) category}.toList();
        parsed.add(
          Quote(
            id: 'local_$i',
            content: content,
            author: author,
            source: null,
            language: 'en',
            isFeatured: false,
            tags: mergedTags,
            createdAt: DateTime(2020, 1, 1).add(Duration(seconds: i)),
          ),
        );
      }

      _localQuotesCache = parsed.isNotEmpty ? parsed : _builtinFallbackQuotes();
      return _localQuotesCache!;
    } catch (_) {
      _localQuotesCache = _builtinFallbackQuotes();
      return _localQuotesCache!;
    }
  }

  Future<List<Quote>> _loadFirestoreQuotes({int maxDocs = 4000}) async {
    final now = DateTime.now();
    if (_firestoreQuotesCache != null && _firestoreQuotesLoadedAt != null) {
      if (now.difference(_firestoreQuotesLoadedAt!) < _firestoreCacheTtl) {
        return _firestoreQuotesCache!;
      }
    }

    final all = <Quote>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    const pageSize = 400;

    try {
      while (all.length < maxDocs) {
        Query<Map<String, dynamic>> query = _db
            .collection('quotes')
            .orderBy('createdAt', descending: true)
            .limit(pageSize);

        if (cursor != null) {
          query = query.startAfterDocument(cursor);
        }

        final snap = await query.get();
        if (snap.docs.isEmpty) break;
        all.addAll(snap.docs.map(Quote.fromFirestore));
        cursor = snap.docs.last;

        if (snap.docs.length < pageSize) break;
      }
    } catch (_) {
      // orderBy 인덱스 문제/권한 문제 등 발생 시 안전 폴백
      try {
        final fallback = await _db.collection('quotes').limit(500).get();
        all
          ..clear()
          ..addAll(fallback.docs.map(Quote.fromFirestore));
      } catch (_) {
        // 오프라인/권한 오류 시 Firestore 결과 없이 로컬 검색으로 진행
      }
    }

    _firestoreQuotesCache = all;
    _firestoreQuotesLoadedAt = now;
    return all;
  }

  List<Quote> _dedupQuotes(List<Quote> quotes) {
    final map = <String, Quote>{};
    for (final q in quotes) {
      final key = '${q.content.toLowerCase()}|${q.author.toLowerCase()}';
      map.putIfAbsent(key, () => q);
    }
    return map.values.toList();
  }

  List<Quote> _filterByLanguage(List<Quote> quotes, String language) {
    if (language == 'all') return quotes;
    final exact = quotes.where((q) => q.language == language).toList();
    if (exact.isNotEmpty) return exact;
    if (language == 'ko') {
      return quotes.where((q) => q.language == 'en').toList();
    }
    return quotes;
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _tokens(String text) {
    return _normalize(text)
        .split(' ')
        .where((t) => t.length >= 2)
        .toList();
  }

  List<Quote> _rankByKeyword(List<Quote> input, String keyword) {
    final qn = _normalize(keyword);
    if (qn.isEmpty) return input;
    final qt = _tokens(keyword);

    int score(Quote q) {
      final c = _normalize(q.content);
      final a = _normalize(q.author);
      final tags = q.tags.map(_normalize).toList();

      var s = 0;
      if (c == qn) s += 120;
      if (c.startsWith(qn)) s += 60;
      if (c.contains(qn)) s += 35;
      if (a.contains(qn)) s += 25;
      for (final t in qt) {
        if (c.contains(t)) s += 12;
        if (a.contains(t)) s += 7;
        if (tags.any((x) => x.contains(t))) s += 10;
      }
      return s;
    }

    final scored = input
        .map((q) => (quote: q, score: score(q)))
        .where((e) => e.score > 0)
        .toList()
      ..sort((x, y) {
        final c = y.score.compareTo(x.score);
        if (c != 0) return c;
        return y.quote.createdAt.compareTo(x.quote.createdAt);
      });

    return scored.map((e) => e.quote).toList();
  }

  Set<String> _expandTagTokens(List<String> tags) {
    final queryTokens = <String>{};
    for (final tag in tags) {
      final lowered = tag.toLowerCase();
      queryTokens.add(lowered);
      queryTokens.addAll(_tagToLocalTokens[tag] ?? const []);
      queryTokens.addAll(_tagToLocalTokens[lowered] ?? const []);
    }
    return queryTokens;
  }

  List<Quote> _rankByTags(List<Quote> input, List<String> tags) {
    final expanded = _expandTagTokens(tags);
    final normalizedTags = tags.map(_normalize).toSet();
    int score(Quote q) {
      final content = _normalize(q.content);
      final author = _normalize(q.author);
      final qtags = q.tags.map(_normalize).toList();
      var s = 0;
      for (final tag in normalizedTags) {
        if (qtags.contains(tag)) s += 40;
        if (content.contains(tag)) s += 16;
        if (author.contains(tag)) s += 6;
      }
      for (final token in expanded) {
        final n = _normalize(token);
        if (n.isEmpty) continue;
        if (qtags.any((t) => t.contains(n))) s += 14;
        if (content.contains(n)) s += 8;
      }
      return s;
    }

    final scored = input
        .map((q) => (quote: q, score: score(q)))
        .where((e) => e.score > 0)
        .toList()
      ..sort((x, y) {
        final c = y.score.compareTo(x.score);
        if (c != 0) return c;
        return y.quote.createdAt.compareTo(x.quote.createdAt);
      });

    return scored.map((e) => e.quote).toList();
  }

  Future<List<Quote>> _localSearchByKeyword(String keyword) async {
    final normalized = keyword.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final local = await _loadLocalQuotes();
    return local.where((q) {
      if (q.content.toLowerCase().contains(normalized)) return true;
      if (q.author.toLowerCase().contains(normalized)) return true;
      return q.tags.any((t) => t.contains(normalized));
    }).toList();
  }

  Future<List<Quote>> _localSearchByTags(List<String> tags) async {
    if (tags.isEmpty) return const [];
    final local = await _loadLocalQuotes();
    final queryTokens = _expandTagTokens(tags);

    return local.where((q) {
      final haystack = '${q.content} ${q.author} ${q.tags.join(' ')}'.toLowerCase();
      return queryTokens.any(haystack.contains);
    }).toList();
  }

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
    final firestoreAll = await _loadFirestoreQuotes();
    final normalized = _normalize(keyword);
    final firestoreMatches = firestoreAll.where((q) {
      final c = _normalize(q.content);
      final a = _normalize(q.author);
      return c.contains(normalized) ||
          a.contains(normalized) ||
          q.tags.any((t) => _normalize(t).contains(normalized));
    }).toList();

    final localMatches = await _localSearchByKeyword(keyword);
    final merged = _filterByLanguage(
      _dedupQuotes([...firestoreMatches, ...localMatches]),
      language,
    );
    final ranked = _rankByKeyword(merged, keyword);

    final page = ranked.skip(offset).take(limit).toList();
    return QuotePage(
      quotes: page,
      hasMore: offset + page.length < ranked.length,
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

    final expanded = _expandTagTokens(tags).map(_normalize).toSet();
    final normalizedTags = tags.map(_normalize).toSet();
    final firestoreAll = await _loadFirestoreQuotes();

    final firestoreMatches = firestoreAll.where((q) {
      final content = _normalize(q.content);
      final author = _normalize(q.author);
      final qtags = q.tags.map(_normalize).toList();

      if (qtags.any(normalizedTags.contains)) return true;
      if (expanded.any((t) => qtags.any((qt) => qt.contains(t)))) return true;
      if (expanded.any(content.contains)) return true;
      if (expanded.any(author.contains)) return true;
      return false;
    }).toList();

    final localMatches = await _localSearchByTags(tags);
    final merged = _filterByLanguage(
      _dedupQuotes([...firestoreMatches, ...localMatches]),
      language,
    );
    final ranked = _rankByTags(merged, tags);

    final page = ranked.skip(offset).take(limit).toList();
    return QuotePage(
      quotes: page,
      hasMore: offset + page.length < ranked.length,
      nextOffset: offset + page.length,
    );
  }

  // -------------------------------------------------------------------------
  // 카테고리 상세용 페이지네이션
  // 정렬/병합 일관성을 위해 searchByTags 기반 offset 페이지네이션 사용
  // -------------------------------------------------------------------------
  /// [tag] 에 해당하는 명언을 [limit]개씩 가져온다.
  /// [offset] 이후부터 다음 페이지를 반환한다.
  /// language 필터는 클라이언트 사이드에서 처리한다.
  Future<TagPageResult> fetchByTagPaginated(
    String tag, {
    DocumentSnapshot? lastDoc,
    int offset = 0,
    int limit = 20,
    String language = 'ko',
  }) async {
    // lastDoc 기반은 유지 호환 용도이며, 실제 페이지네이션은 offset으로 처리
    final page = await searchByTags(
      [tag],
      offset: offset,
      limit: limit,
      language: language,
    );

    return TagPageResult(
      quotes: page.quotes,
      lastDoc: null,
      hasMore: page.hasMore,
      nextOffset: page.nextOffset,
    );
  }
}

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => QuoteRepository(ref.watch(firestoreProvider)),
);

// ---------------------------------------------------------------------------
// TagPageResult (태그 상세 페이지네이션 결과)
// ---------------------------------------------------------------------------
class TagPageResult {
  final List<Quote> quotes;

  /// 레거시 호환용 필드 (현재는 사용하지 않음)
  final DocumentSnapshot? lastDoc;

  /// 더 불러올 데이터가 있는지 여부
  final bool hasMore;
  final int nextOffset;

  const TagPageResult({
    required this.quotes,
    this.lastDoc,
    required this.hasMore,
    required this.nextOffset,
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
