import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import 'user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  Future<UserProfile?> fetchProfile(String uid) async {
    if (uid.trim().isEmpty) return null;
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.data() ?? const {});
  }

  Future<void> saveProfile(UserProfile profile) async {
    if (profile.uid.trim().isEmpty) {
      throw ArgumentError('uid가 비어 있습니다.');
    }

    final data = {
      ...profile.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _users.doc(profile.uid).set(data, SetOptions(merge: true));
  }

  Future<UserProfile> resolveEffectiveProfile(User user) async {
    final saved = await fetchProfile(user.uid);
    if (saved != null) return saved;

    final authName = user.displayName?.trim() ?? '';
    final fallbackName = authName.isNotEmpty
        ? authName
        : (user.email?.split('@').first ?? (user.isAnonymous ? 'Guest' : 'User'));
    return UserProfile(
      uid: user.uid,
      displayName: fallbackName,
      avatarEmoji: '🐣',
      avatarImageDataUrl: null,
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(firestoreProvider)),
);

final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return repo.resolveEffectiveProfile(user);
});
