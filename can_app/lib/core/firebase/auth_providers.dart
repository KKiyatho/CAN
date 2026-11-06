import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://xlqqeypfomtvkxeyyxek.supabase.co';
const supabasePublishableKey = 'sb_publishable_VVPXLJBHNaZaaub6-RlgNg_Q7wa5B0Z';

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
  await supabase.auth.signOut();
}
