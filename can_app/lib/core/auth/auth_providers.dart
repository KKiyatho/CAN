import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/user_data.dart';

class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.isAnonymous = false,
  });

  final String id;
  final String? email;
  final String? displayName;
  final bool isAnonymous;

  static AppUser? fromSession(Session? session) {
    final user = session?.user;
    if (user == null) return null;
    final metadata = user.userMetadata ?? const {};
    final display = metadata['full_name'] as String? ??
        metadata['name'] as String? ??
        user.email?.split('@').first;
    return AppUser(
      id: user.id,
      email: user.email,
      displayName: display,
      isAnonymous: user.isAnonymous,
    );
  }

  static AppUser? fromSupabaseUser(User? user) {
    if (user == null) return null;
    final metadata = user.userMetadata ?? const {};
    final display = metadata['full_name'] as String? ??
        metadata['name'] as String? ??
        user.email?.split('@').first;
    return AppUser(
      id: user.id,
      email: user.email,
      displayName: display,
      isAnonymous: user.isAnonymous,
    );
  }
}

final supabaseClientProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((event) => AppUser.fromSession(event.session));
});

final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.id;
});

Future<AppUser?> signInAnonymouslyIfNeeded([SupabaseClient? client]) async {
  final supabase = client ?? Supabase.instance.client;
  final existing = AppUser.fromSupabaseUser(supabase.auth.currentUser);
  if (existing != null) return existing;

  final response = await supabase.auth.signInAnonymously();
  return AppUser.fromSupabaseUser(response.user);
}

Future<void> signOutCurrentUser([SupabaseClient? client]) async {
  final supabase = client ?? Supabase.instance.client;
  try {
    await supabase.auth.signOut();
  } finally {
    await clearUserLocalData();
  }
}

/// 서버의 계정·프로필·게시글을 삭제한 뒤 이 기기의 세션과 개인 데이터를 정리한다.
Future<void> deleteCurrentAccount([SupabaseClient? client]) async {
  final supabase = client ?? Supabase.instance.client;
  await supabase.rpc('delete_my_account');
  try {
    await supabase.auth.signOut(scope: SignOutScope.local);
  } catch (_) {
    // 계정이 이미 삭제되어 서버 로그아웃이 거부되어도 로컬 세션은 정리된다.
  }
  await clearUserLocalData();
}
