import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/quote.dart';

const _kBookmarksKey = 'bookmarked_quote_ids';
const _kLikesKey = 'liked_quote_ids';
const _kDeviceIdKey = 'device_id';
const _kAiQuotesKey = 'ai_quotes_cache';
const _kAiQuotesMax = 200;

// ---------------------------------------------------------------------------
// QuoteRepository
// ---------------------------------------------------------------------------
class QuoteRepository {
  QuoteRepository();

  /// 감정 추천 API (Azure Functions + Azure OpenAI). 빌드 시 --dart-define 으로 교체 가능.
  static const String _recommendUrl = String.fromEnvironment(
    'CAN_RECOMMEND_URL',
    defaultValue: 'https://can-api-55425.azurewebsites.net/api/recommend',
  );

  static List<Quote>? _curatedKo;
  static List<Quote>? _curatedEn;

  /// 실존 인물 명언 (assets/quotes_curated.json) 로드.
  /// 직업 카테고리는 `job:<직업명>` 태그로 구분한다.
  Future<void> _ensureCurated() async {
    if (_curatedKo != null && _curatedEn != null) return;
    final raw = await rootBundle.loadString('assets/quotes_curated.json');
    final list = jsonDecode(raw) as List<dynamic>;
    final ko = <Quote>[];
    final en = <Quote>[];
    final base = DateTime(2020, 1, 1);
    for (var i = 0; i < list.length; i++) {
      final m = list[i] as Map<String, dynamic>;
      final id = m['id'] as String;
      final topics =
          (m['topics'] as List<dynamic>? ?? const []).cast<String>();
      final occupation = m['occupation'] as String?;
      final tags = [
        ...topics,
        if (occupation != null && occupation.isNotEmpty) 'job:$occupation',
      ];
      final createdAt = base.add(Duration(seconds: i));
      final source = m['source'] as String?;
      ko.add(Quote(
        id: id,
        content: m['ko'] as String,
        author: m['authorKo'] as String,
        source: source,
        language: 'ko',
        isFeatured: false,
        tags: tags,
        createdAt: createdAt,
      ));
      en.add(Quote(
        id: '${id}_en',
        content: m['en'] as String,
        author: m['authorEn'] as String,
        source: source,
        language: 'en',
        isFeatured: false,
        tags: tags,
        createdAt: createdAt,
      ));
    }
    _curatedKo = ko;
    _curatedEn = en;
  }

  Future<List<Quote>> _quotesFor(String language) async {
    await _ensureCurated();
    if (language == 'ko') return _curatedKo!;
    if (language == 'all') return [..._curatedKo!, ..._curatedEn!];
    return _curatedEn!;
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _tokens(String text) {
    return _normalize(text).split(' ').where((t) => t.length >= 2).toList();
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
      ..sort((x, y) => y.score.compareTo(x.score));

    return scored.map((e) => e.quote).toList();
  }

  Future<Quote> fetchFeaturedQuote({String language = 'ko'}) async {
    final local = await _quotesFor(language);
    if (local.isEmpty) {
      throw Exception('명언 데이터가 없습니다.');
    }
    return local[Random().nextInt(local.length)];
  }

  Future<QuotePage> searchByKeyword(
    String keyword, {
    int offset = 0,
    int limit = 20,
    String language = 'ko',
  }) async {
    final source = await _quotesFor(language);
    final ranked = _rankByKeyword(source, keyword);
    final page = ranked.skip(offset).take(limit).toList();
    return QuotePage(
      quotes: page,
      hasMore: offset + page.length < ranked.length,
      nextOffset: offset + page.length,
    );
  }

  Future<QuotePage> searchByTags(
    List<String> tags, {
    int offset = 0,
    int limit = 20,
    String language = 'ko',
  }) async {
    if (tags.isEmpty) {
      return const QuotePage(quotes: [], hasMore: false, nextOffset: 0);
    }
    final source = await _quotesFor(language);
    final matched = <(Quote, int)>[];
    for (final q in source) {
      final hit = tags.where(q.tags.contains).length;
      if (hit > 0) matched.add((q, hit));
    }
    matched.sort((a, b) => b.$2.compareTo(a.$2));
    final resolved = matched.map((e) => e.$1).toList();
    final page = resolved.skip(offset).take(limit).toList();
    return QuotePage(
      quotes: page,
      hasMore: offset + page.length < resolved.length,
      nextOffset: offset + page.length,
    );
  }

  Future<TagPageResult> fetchByTagPaginated(
    String tag, {
    Object? lastDoc,
    int offset = 0,
    int limit = 20,
    String language = 'ko',
  }) async {
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

  Future<List<Quote>> fetchQuotesByIds(
    Iterable<String> quoteIds, {
    String language = 'all',
  }) async {
    final ids = quoteIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return const [];
    final source = await _quotesFor('all');
    final map = {for (final q in source) q.id: q};
    for (final q in await _loadAiQuotes()) {
      map[q.id] = q;
    }
    final ordered = ids.map((id) => map[id]).whereType<Quote>().toList();
    if (language == 'all') return ordered;
    return ordered.where((q) => q.language == language).toList();
  }

  /// Azure OpenAI 기반 감정 추천: 실존 인물 명언 1개 + 짧은 공감 메시지.
  /// 실패 시 null 반환 (호출 측에서 로컬 검색으로 폴백).
  Future<AiRecommendation?> recommendByEmotion(
    String input, {
    String language = 'ko',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(_recommendUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'input': input, 'lang': language}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final main = _aiQuote(data['quote'], language);
      if (main == null) return null;
      final similar = (data['similar'] as List<dynamic>? ?? const [])
          .map((e) => _aiQuote(e, language))
          .whereType<Quote>()
          .toList();
      await _saveAiQuotes([main, ...similar]);
      return AiRecommendation(
        quote: main,
        similar: similar,
        message: (data['message'] as String?)?.trim() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// AI 명언 영속 캐시 (북마크/좋아요 목록에서 다시 찾을 수 있도록 보관)
  Future<List<Quote>> _loadAiQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kAiQuotesKey) ?? const [];
    final out = <Quote>[];
    for (final s in raw) {
      try {
        out.add(Quote.fromMap(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  Future<void> _saveAiQuotes(List<Quote> fresh) async {
    final prefs = await SharedPreferences.getInstance();
    final keep = {
      ...(prefs.getStringList(_kBookmarksKey) ?? const <String>[]),
      ...(prefs.getStringList(_kLikesKey) ?? const <String>[]),
    };
    final byId = {for (final q in await _loadAiQuotes()) q.id: q};
    for (final q in fresh) {
      byId[q.id] = q;
    }
    // 오래된 것부터 제거하되 북마크/좋아요된 명언은 유지
    final ids = byId.keys.toList();
    var overflow = ids.length - _kAiQuotesMax;
    for (final id in ids) {
      if (overflow <= 0) break;
      if (!keep.contains(id)) {
        byId.remove(id);
        overflow--;
      }
    }
    await prefs.setStringList(
      _kAiQuotesKey,
      byId.values.map((q) => jsonEncode(q.toMap())).toList(),
    );
  }

  /// AI 가 찾아온 명언 JSON → Quote (로컬 데이터셋에 없는 외부 명언)
  Quote? _aiQuote(Object? raw, String language) {
    if (raw is! Map<String, dynamic>) return null;
    final content = (raw['content'] as String?)?.trim() ?? '';
    final author = (raw['author'] as String?)?.trim() ?? '';
    if (content.isEmpty || author.isEmpty) return null;
    return Quote(
      id: 'ai_${content.hashCode}',
      content: content,
      author: author,
      source: raw['source'] as String?,
      language: language,
      isFeatured: false,
      createdAt: DateTime.now(),
    );
  }
}

class AiRecommendation {
  final Quote quote;
  final List<Quote> similar;
  final String message;
  const AiRecommendation({
    required this.quote,
    this.similar = const [],
    required this.message,
  });
}

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (_) => QuoteRepository(),
);

// ---------------------------------------------------------------------------
// TagPageResult (태그 상세 페이지네이션 결과)
// ---------------------------------------------------------------------------
class TagPageResult {
  final List<Quote> quotes;

  /// 레거시 호환용 필드 (현재는 사용하지 않음)
  final Object? lastDoc;

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
