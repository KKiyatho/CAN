import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Firebase Auth 인스턴스 Provider
// ---------------------------------------------------------------------------
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);

// ---------------------------------------------------------------------------
// 현재 로그인 사용자 스트림 Provider
// ---------------------------------------------------------------------------
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// ---------------------------------------------------------------------------
// 현재 사용자 UID Provider — Anonymous Auth 자동 로그인 포함
// null이면 아직 로그인 전, 로그인 후에는 uid 반환
// ---------------------------------------------------------------------------
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.uid;
});

// ---------------------------------------------------------------------------
// Anonymous 로그인 함수 (앱 시작 시 1회 호출)
// ---------------------------------------------------------------------------
Future<User?> signInAnonymouslyIfNeeded(FirebaseAuth auth) async {
  if (auth.currentUser != null) return auth.currentUser;
  final credential = await auth.signInAnonymously();
  return credential.user;
}
