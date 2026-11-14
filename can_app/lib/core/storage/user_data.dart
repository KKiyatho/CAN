import 'package:shared_preferences/shared_preferences.dart';

/// 사용자 개인 활동을 담는 기기 로컬 저장 키.
/// 로그아웃·계정 삭제 시 함께 지워 공용 기기에서 다음 사용자에게 노출되지 않게 한다.
const kBookmarksKey = 'bookmarked_quote_ids';
const kLikesKey = 'liked_quote_ids';
const kAiQuotesKey = 'ai_quotes_cache';
const kRecentSearchesKey = 'recent_searches';

const _kUserDataKeys = [
  kBookmarksKey,
  kLikesKey,
  kAiQuotesKey,
  kRecentSearchesKey,
];

Future<void> clearUserLocalData() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in _kUserDataKeys) {
    await prefs.remove(key);
  }
}
