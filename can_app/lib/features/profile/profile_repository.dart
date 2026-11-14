import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_providers.dart';
import 'user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<UserProfile?> fetchProfile(String uid) async {
    if (uid.trim().isEmpty) return null;
    final row = await _client
        .from('profiles')
        .select('display_name, avatar_emoji, avatar_image_data_url')
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromMap({
      'uid': uid,
      'displayName': row['display_name'],
      'avatarEmoji': row['avatar_emoji'],
      'avatarImageDataUrl': row['avatar_image_data_url'],
    });
  }

  Future<void> saveProfile(UserProfile profile) async {
    if (profile.uid.trim().isEmpty) {
      throw ArgumentError('uid가 비어 있습니다.');
    }
    final image = profile.avatarImageDataUrl;
    await _client.from('profiles').upsert({
      'user_id': profile.uid,
      'display_name': profile.displayName.trim(),
      'avatar_emoji': profile.avatarEmoji,
      'avatar_image_data_url': image == null || image.isEmpty ? null : image,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// 저장된 프로필이 있으면 사용하고, 없으면 계정 정보로 기본 프로필을 만든다(저장하지는 않는다).
  Future<UserProfile> resolveEffectiveProfile(AppUser user) async {
    UserProfile? saved;
    try {
      saved = await fetchProfile(user.id);
    } catch (_) {
      // 일시적인 네트워크 오류로 화면이 막히지 않도록 기본 프로필로 대체한다.
    }
    if (saved != null) return saved;

    final authName = user.displayName?.trim() ?? '';
    final fallbackName = authName.isNotEmpty
        ? authName
        : (user.email?.split('@').first ??
              (user.isAnonymous ? 'Guest' : 'User'));
    return UserProfile(
      uid: user.id,
      displayName: String.fromCharCodes(fallbackName.runes.take(20)),
      avatarEmoji: '🐣',
      avatarImageDataUrl: null,
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return repo.resolveEffectiveProfile(user);
});
