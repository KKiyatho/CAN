import 'dart:convert';

import 'package:can_app/core/storage/user_data.dart';
import 'package:can_app/features/community/community_post.dart';
import 'package:can_app/features/home/quote_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _apiBody() => {
  'message': '힘내세요',
  'quote': {'content': '천 리 길도 한 걸음부터', 'author': '노자', 'source': null},
  'similar': [
    {'content': '시작이 반이다', 'author': '아리스토텔레스', 'source': null},
  ],
};

void main() {
  group('QuoteRepository.recommendByEmotion', () {
    test('로그인 세션이 없으면 서버를 호출하지 않고 null을 돌려준다', () async {
      var calls = 0;
      final repo = QuoteRepository(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
        accessToken: () async => null,
      );
      expect(await repo.recommendByEmotion('불안해요'), isNull);
      expect(calls, 0);
    });

    test('액세스 토큰을 Bearer로 보내고 응답을 명언으로 변환한다', () async {
      SharedPreferences.setMockInitialValues({});
      late http.Request sent;
      final repo = QuoteRepository(
        client: MockClient((request) async {
          sent = request;
          return http.Response.bytes(
            utf8.encode(jsonEncode(_apiBody())),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        accessToken: () async => 'token-123',
      );
      final result = await repo.recommendByEmotion('불안해요');
      expect(sent.headers['Authorization'], 'Bearer token-123');
      expect(jsonDecode(sent.body), {'input': '불안해요', 'lang': 'ko'});
      expect(result!.quote.author, '노자');
      expect(result.similar, hasLength(1));
      expect(result.message, '힘내세요');
    });

    test('같은 명언은 실행 간에도 같은 ID를 갖는다', () async {
      SharedPreferences.setMockInitialValues({});
      Future<String> idOf() async {
        final repo = QuoteRepository(
          client: MockClient(
            (_) async => http.Response.bytes(
              utf8.encode(jsonEncode(_apiBody())),
              200,
            ),
          ),
          accessToken: () async => 't',
        );
        return (await repo.recommendByEmotion('x'))!.quote.id;
      }

      final first = await idOf();
      expect(first, matches(RegExp(r'^ai_[0-9a-f]{8}$')));
      expect(await idOf(), first);
    });

    test('서버 오류·차단·네트워크 실패는 null로 대체 경로를 연다', () async {
      for (final status in [401, 429, 502, 503]) {
        final repo = QuoteRepository(
          client: MockClient((_) async => http.Response('{}', status)),
          accessToken: () async => 't',
        );
        expect(await repo.recommendByEmotion('x'), isNull, reason: '$status');
      }
      final failing = QuoteRepository(
        client: MockClient((_) async => throw http.ClientException('offline')),
        accessToken: () async => 't',
      );
      expect(await failing.recommendByEmotion('x'), isNull);
    });
  });

  group('CommunityPost.fromRow', () {
    test('게시글 행과 작성자 프로필을 매핑한다', () {
      final post = CommunityPost.fromRow({
        'id': 'p1',
        'user_id': 'u1',
        'title': ' 제목 ',
        'content': ' 내용입니다 ',
        'like_count': 3,
        'created_at': '2026-11-14T01:02:03.456789+00:00',
        'profiles': {
          'display_name': '민준',
          'avatar_emoji': '🦊',
          'avatar_image_data_url': null,
        },
      });
      expect(post.title, '제목');
      expect(post.content, '내용입니다');
      expect(post.likeCount, 3);
      expect(post.displayName, '민준');
      expect(post.avatarEmoji, '🦊');
      expect(post.avatarImageDataUrl, isNull);
      expect(post.createdAt.toUtc().year, 2026);
    });

    test('프로필이 없어도 기본값으로 표시한다', () {
      final post = CommunityPost.fromRow({
        'id': 'p2',
        'user_id': 'u2',
        'title': 't',
        'content': 'cc',
        'like_count': 0,
        'created_at': '2026-11-14T00:00:00Z',
      });
      expect(post.displayName, 'Guest');
      expect(post.avatarEmoji, '🐣');
    });
  });

  test('clearUserLocalData는 개인 활동 기록만 지우고 설정은 유지한다', () async {
    SharedPreferences.setMockInitialValues({
      kBookmarksKey: ['q1'],
      kLikesKey: ['q2'],
      kAiQuotesKey: ['{}'],
      kRecentSearchesKey: ['불안'],
      'theme_language_code': 'en',
    });
    await clearUserLocalData();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(kBookmarksKey), isNull);
    expect(prefs.getStringList(kLikesKey), isNull);
    expect(prefs.getStringList(kAiQuotesKey), isNull);
    expect(prefs.getStringList(kRecentSearchesKey), isNull);
    expect(prefs.getString('theme_language_code'), 'en');
  });
}
