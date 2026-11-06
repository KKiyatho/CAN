import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import 'user_profile.dart';

class ProfileRepository {
  static final Map<String, UserProfile> _profiles = <String, UserProfile>{};

  ProfileRepository();

  Future<UserProfile?> fetchProfile(String uid) async {
    if (uid.trim().isEmpty) return null;
    return _profiles[uid];
  }

  Future<void> saveProfile(UserProfile profile) async {
    if (profile.uid.trim().isEmpty) {
      throw ArgumentError('uid가 비어 있습니다.');
    }
    _profiles[profile.uid] = profile;
  }

  Future<UserProfile> resolveEffectiveProfile(AppUser user) async {
    final saved = await fetchProfile(user.id);
    if (saved != null) return saved;

    final authName = user.displayName?.trim() ?? '';
    final fallbackName = authName.isNotEmpty
        ? authName
        : (user.email?.split('@').first ?? (user.isAnonymous ? 'Guest' : 'User'));
    return UserProfile(
      uid: user.id,
      displayName: fallbackName,
      avatarEmoji: '🐣',
      avatarImageDataUrl: null,
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (_) => ProfileRepository(),
);

final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return repo.resolveEffectiveProfile(user);
});
