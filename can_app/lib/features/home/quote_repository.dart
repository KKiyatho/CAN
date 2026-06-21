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
  static List<Quote>? _localKoreanQuotesCache;
  static List<Quote>? _builtinEnglishQuotesCache;
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

  static const List<Map<String, dynamic>> _koreanFallbackSeed = [
    {'content': '불안은 멈추라는 신호가 아니라, 방향을 점검하라는 신호다.', 'tags': ['불안', '삶', '자기계발']},
    {'content': '완벽한 시작보다 오늘의 시작이 더 중요하다.', 'tags': ['자기계발', '도전', '성공']},
    {'content': '작은 성실이 큰 자신감을 만든다.', 'tags': ['자기계발', '성공', '용기']},
    {'content': '포기하고 싶은 날에도 한 줄은 남겨라.', 'tags': ['지침', '도전', '독서']},
    {'content': '생각이 복잡할수록 해야 할 일은 단순해진다.', 'tags': ['철학', '삶', '자기계발']},
    {'content': '비교는 속도를 빼앗고, 집중은 방향을 만든다.', 'tags': ['자기계발', '성공', '삶']},
    {'content': '용기는 두려움이 없는 상태가 아니라, 두려움과 함께 걷는 태도다.', 'tags': ['용기', '불안', '도전']},
    {'content': '오늘의 선택이 내일의 습관이 된다.', 'tags': ['자기계발', '삶', '성공']},
    {'content': '느리게 가도 멈추지 않으면 도착한다.', 'tags': ['도전', '지침', '성공']},
    {'content': '한 번의 실패는 방향 수정이지 인생 판정이 아니다.', 'tags': ['도전', '성공', '삶']},
    {'content': '진짜 실력은 조용한 반복에서 자란다.', 'tags': ['자기계발', '성공', '지혜']},
    {'content': '면접은 평가의 자리이기도 하지만, 선택의 자리이기도 하다.', 'tags': ['면접', '용기', '성공']},
    {'content': '질문을 잘하는 사람이 기회를 먼저 본다.', 'tags': ['면접', '지혜', '성공']},
    {'content': '대답보다 태도가 오래 기억된다.', 'tags': ['면접', '관계', '자기계발']},
    {'content': '사랑은 상대를 바꾸는 힘이 아니라, 이해하려는 힘이다.', 'tags': ['사랑', '관계', '행복']},
    {'content': '좋은 관계는 자주 말하는 것보다 잘 듣는 것에서 시작된다.', 'tags': ['관계', '사랑', '지혜']},
    {'content': '진심은 빠른 답장보다 정확한 공감에 가깝다.', 'tags': ['관계', '사랑', '행복']},
    {'content': '행복은 커다란 사건보다 잦은 감사에 가깝다.', 'tags': ['행복', '삶', '믿음']},
    {'content': '웃음은 문제를 없애지 못해도 버틸 힘을 준다.', 'tags': ['행복', '지침', '삶']},
    {'content': '마음이 흔들릴 때는 해야 할 일을 줄여라.', 'tags': ['불안', '지침', '자기계발']},
    {'content': '철학은 어려운 답이 아니라 깊은 질문에서 시작된다.', 'tags': ['철학', '지혜', '삶']},
    {'content': '자유는 하고 싶은 것을 다 하는 것이 아니라, 해야 할 것을 선택하는 힘이다.', 'tags': ['철학', '삶', '용기']},
    {'content': '진실은 편안함보다 오래 남는다.', 'tags': ['철학', '지혜', '관계']},
    {'content': '지혜는 많이 아는 것이 아니라, 지금 필요한 것을 아는 능력이다.', 'tags': ['지혜', '삶', '자기계발']},
    {'content': '배움은 기억의 양이 아니라 시선의 변화다.', 'tags': ['지혜', '독서', '자기계발']},
    {'content': '책은 답을 주기보다 질문의 깊이를 바꾼다.', 'tags': ['독서', '지혜', '철학']},
    {'content': '읽은 문장은 사라져도 남은 태도는 삶을 바꾼다.', 'tags': ['독서', '삶', '자기계발']},
    {'content': '창의력은 영감보다 관찰에서 먼저 태어난다.', 'tags': ['창의력', '지혜', '도전']},
    {'content': '새로운 생각은 익숙한 것을 다르게 부를 때 시작된다.', 'tags': ['창의력', '철학', '자기계발']},
    {'content': '도전은 큰 결심보다 작은 실행의 누적이다.', 'tags': ['도전', '자기계발', '성공']},
    {'content': '성공은 속도보다 지속성에 더 가깝다.', 'tags': ['성공', '자기계발', '지침']},
    {'content': '꾸준함은 재능이 없어도 쌓을 수 있는 가장 공정한 자산이다.', 'tags': ['성공', '자기계발', '용기']},
    {'content': '믿음은 결과를 아는 확신이 아니라, 과정을 견디는 힘이다.', 'tags': ['믿음', '지침', '삶']},
    {'content': '기도는 문제를 지우는 주문이 아니라 마음을 세우는 시간이다.', 'tags': ['믿음', '불안', '행복']},
    {'content': '삶은 정답지를 찾는 여행이 아니라 나만의 문장을 쓰는 과정이다.', 'tags': ['삶', '철학', '자기계발']},
    {'content': '오늘을 견딘 사람에게 내일은 선물이 된다.', 'tags': ['삶', '지침', '희망']},
    {'content': '희망은 상황이 좋아서 생기는 감정이 아니라 포기하지 않는 선택이다.', 'tags': ['희망', '도전', '삶']},
    {'content': '불안한 밤에는 계획보다 호흡을 먼저 챙겨라.', 'tags': ['불안', '행복', '삶']},
    {'content': '지친 마음은 더 세게 밀기보다 잠깐 멈춰야 회복된다.', 'tags': ['지침', '행복', '삶']},
    {'content': '면접장에서 필요한 것은 완벽함이 아니라 명확함이다.', 'tags': ['면접', '용기', '자기계발']},
    {'content': '좋은 답변은 외운 문장이 아니라 경험에서 나온 문장이다.', 'tags': ['면접', '지혜', '성공']},
    {'content': '관계의 품격은 갈등이 없을 때가 아니라 갈등을 다루는 방식에서 드러난다.', 'tags': ['관계', '사랑', '지혜']},
    {'content': '사랑은 확신을 요구하기보다 성장을 허락한다.', 'tags': ['사랑', '관계', '행복']},
    {'content': '행복은 멀리 있는 목표가 아니라 가까이 있는 태도다.', 'tags': ['행복', '삶', '철학']},
    {'content': '철학은 삶을 느리게 만들지 않는다. 더 정확하게 만든다.', 'tags': ['철학', '지혜', '삶']},
    {'content': '지혜로운 사람은 말의 크기보다 침묵의 길이를 안다.', 'tags': ['지혜', '관계', '철학']},
    {'content': '독서는 시간을 쓰는 일이 아니라 시야를 넓히는 일이다.', 'tags': ['독서', '지혜', '자기계발']},
    {'content': '창의력은 틀을 부수는 힘이 아니라 틀을 다시 설계하는 힘이다.', 'tags': ['창의력', '도전', '지혜']},
    {'content': '도전은 불확실함을 없애는 일이 아니라 불확실함과 친해지는 일이다.', 'tags': ['도전', '불안', '용기']},
    {'content': '성공은 크게 이기는 날보다 무너지지 않는 날들로 완성된다.', 'tags': ['성공', '지침', '삶']},
    {'content': '삶의 방향은 남의 박수보다 내 마음의 평온이 결정한다.', 'tags': ['삶', '행복', '철학']},
  ];

  static List<Quote> _builtinKoreanQuotes() {
    if (_localKoreanQuotesCache != null) return _localKoreanQuotesCache!;
    final now = DateTime(2020, 1, 1);
    _localKoreanQuotesCache = _koreanFallbackSeed
      .take(50)
      .toList()
        .asMap()
        .entries
        .map(
          (entry) => Quote(
            id: 'builtin_ko_${entry.key + 1}',
            content: entry.value['content'] as String,
            author: 'CAN',
            source: null,
            language: 'ko',
            isFeatured: false,
            tags: List<String>.from(entry.value['tags'] as List<dynamic>),
            createdAt: now.add(Duration(seconds: entry.key)),
          ),
        )
        .toList();
    return _localKoreanQuotesCache!;
  }

  static List<Quote> _builtinEnglishQuotes() {
    if (_builtinEnglishQuotesCache != null) return _builtinEnglishQuotesCache!;
    final now = DateTime(2020, 1, 1, 0, 10);
    _builtinEnglishQuotesCache = [
      Quote(
        id: 'builtin_en_1',
        content: 'Progress is built by showing up on ordinary days.',
        author: 'CAN',
        source: null,
        language: 'en',
        isFeatured: false,
        tags: const ['motivation', 'growth', 'success'],
        createdAt: now,
      ),
      Quote(
        id: 'builtin_en_2',
        content: 'Courage is taking one more step while still feeling afraid.',
        author: 'CAN',
        source: null,
        language: 'en',
        isFeatured: false,
        tags: const ['courage', 'life', 'strength'],
        createdAt: now.add(const Duration(seconds: 1)),
      ),
      Quote(
        id: 'builtin_en_3',
        content: 'Consistency can outrun talent when talent stops early.',
        author: 'CAN',
        source: null,
        language: 'en',
        isFeatured: false,
        tags: const ['success', 'discipline', 'work'],
        createdAt: now.add(const Duration(seconds: 2)),
      ),
    ];
    return _builtinEnglishQuotesCache!;
  }

  List<Quote> _builtinQuotesForLanguage(String language) {
    if (language == 'all') {
      return [..._builtinKoreanQuotes(), ..._builtinEnglishQuotes()];
    }
    if (language == 'ko') return _builtinKoreanQuotes();
    return _builtinEnglishQuotes();
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

      _localQuotesCache = parsed.isNotEmpty ? parsed : _builtinEnglishQuotes();
      return _localQuotesCache!;
    } catch (_) {
      _localQuotesCache = _builtinEnglishQuotes();
      return _localQuotesCache!;
    }
  }

  Future<List<Quote>> _loadLocalQuotesForLanguage(String language) async {
    if (language == 'ko') {
      return _builtinKoreanQuotes();
    }
    if (language == 'all') {
      final en = await _loadLocalQuotes();
      return [...en, ..._builtinKoreanQuotes()];
    }
    return _loadLocalQuotes();
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
    return quotes.where((q) => q.language == language).toList();
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

  List<Quote> _supplementKoreanByTags(
    List<Quote> current,
    List<String> tags,
  ) {
    final fallback = _builtinKoreanQuotes();
    final rankedFallback = _rankByTags(fallback, tags);
    final merged = _dedupQuotes([
      ...current,
      ...rankedFallback,
      ...fallback,
    ]);
    return merged;
  }

  Future<List<Quote>> _localSearchByTags(List<String> tags, {String language = 'en'}) async {
    if (tags.isEmpty) return const [];
    final local = await _loadLocalQuotesForLanguage(language);
    final queryTokens = _expandTagTokens(tags);

    return local.where((q) {
      final haystack = '${q.content} ${q.author} ${q.tags.join(' ')}'.toLowerCase();
      return queryTokens.any(haystack.contains);
    }).toList();
  }

  Future<List<Quote>> _firestoreSearchByTags(List<String> tags) async {
    if (tags.isEmpty) return const [];
    final normalizedTags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    if (normalizedTags.isEmpty) return const [];

    final queryTags = normalizedTags.take(10).toList();
    try {
      final snapshot = await _db
          .collection('quotes')
          .where('tags', arrayContainsAny: queryTags)
          .limit(200)
          .get();
      return snapshot.docs.map(Quote.fromFirestore).toList();
    } catch (_) {
      try {
        final fallback = await _db
            .collection('quotes')
            .where('tags', arrayContains: queryTags.first)
            .limit(200)
            .get();
        return fallback.docs.map(Quote.fromFirestore).toList();
      } catch (_) {
        return const [];
      }
    }
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
      if (language == 'ko') {
        final localKo = await _loadLocalQuotesForLanguage('ko');
        if (localKo.isNotEmpty) {
          final koFeatured = localKo.where((q) => q.isFeatured).toList()..shuffle();
          if (koFeatured.isNotEmpty) return koFeatured.first;
          return localKo.first;
        }
      }
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
    final firestoreAll = await _loadFirestoreQuotes(maxDocs: 1500);
    final normalized = _normalize(keyword);
    final firestoreMatches = firestoreAll.where((q) {
      final c = _normalize(q.content);
      final a = _normalize(q.author);
      return c.contains(normalized) ||
          a.contains(normalized) ||
          q.tags.any((t) => _normalize(t).contains(normalized));
    }).toList();

    final localSource = await _loadLocalQuotesForLanguage(language);
    final localMatches = localSource.where((q) {
      final content = _normalize(q.content);
      final author = _normalize(q.author);
      return content.contains(normalized) ||
          author.contains(normalized) ||
          q.tags.any((t) => _normalize(t).contains(normalized));
    }).toList();
    final merged = _filterByLanguage(
      _dedupQuotes([...firestoreMatches, ...localMatches]),
      language,
    );
    final ranked = _rankByKeyword(merged, keyword);
    final resolved = ranked.isNotEmpty ? ranked : _builtinQuotesForLanguage(language);

    final page = resolved.skip(offset).take(limit).toList();
    return QuotePage(
      quotes: page,
      hasMore: offset + page.length < resolved.length,
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

    final firestoreMatches = await _firestoreSearchByTags(tags);
    final localMatches = await _localSearchByTags(tags, language: language);
    final merged = _filterByLanguage(
      _dedupQuotes([...firestoreMatches, ...localMatches]),
      language,
    );
    final ranked = _rankByTags(merged, tags);
    var resolved =
        ranked.isNotEmpty ? ranked : _builtinQuotesForLanguage(language);
    if (language == 'ko') {
      resolved = _supplementKoreanByTags(resolved, tags);
    }

    final page = resolved.skip(offset).take(limit).toList();
    return QuotePage(
      quotes: page,
      hasMore: offset + page.length < resolved.length,
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

  Future<List<Quote>> fetchQuotesByIds(
    Iterable<String> quoteIds, {
    String language = 'all',
  }) async {
    final orderedIds = quoteIds
        .where((id) => id.trim().isNotEmpty)
        .toList(growable: false);
    if (orderedIds.isEmpty) return const [];

    final map = <String, Quote>{};

    final missing = <String>[];
    for (var i = 0; i < orderedIds.length; i += 10) {
      final chunk = orderedIds.skip(i).take(10).toList();
      try {
        final snap = await _db
            .collection('quotes')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final quote = Quote.fromFirestore(doc);
          map[quote.id] = quote;
        }
      } catch (_) {
        missing.addAll(chunk);
      }
    }

    final unresolved = orderedIds.where((id) => !map.containsKey(id)).toSet()
      ..addAll(missing);
    if (unresolved.isNotEmpty) {
      final local = await _loadLocalQuotesForLanguage('all');
      for (final quote in local) {
        if (unresolved.contains(quote.id)) {
          map[quote.id] = quote;
        }
      }
      final builtin = _builtinQuotesForLanguage('all');
      for (final quote in builtin) {
        if (unresolved.contains(quote.id)) {
          map[quote.id] = quote;
        }
      }
    }

    final ordered = orderedIds
        .map((id) => map[id])
        .whereType<Quote>()
        .toList(growable: false);
    return _filterByLanguage(ordered, language);
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
