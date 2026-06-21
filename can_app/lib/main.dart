import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_shell.dart';
import 'core/firebase/auth_providers.dart';
import 'core/theme/theme_notifier.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter Web 특정 환경에서 키보드 dismiss 타이밍에 발생하는
  // viewInsets assertion을 앱 크래시로 전파하지 않도록 방어한다.
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    final message = error.toString();
    if (message.contains('_viewInsets.isNonNegative') ||
        message.contains('ViewInsets cannot be negative')) {
      debugPrint('[WebInsetsGuard] ignored: $message');
      return true;
    }
    return false;
  };

  // 웹에서 AssetManifest 이슈가 있을 때 google_fonts 반복 로드를 차단
  GoogleFonts.config.allowRuntimeFetching = false;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: CanApp()));
}

class CanApp extends ConsumerWidget {
  const CanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(themeNotifierProvider.notifier).loadSaved();
    });

    final themeState = ref.watch(themeNotifierProvider);
    final themeData = buildThemeData(themeState);
    final authAsync = ref.watch(authStateProvider);

    // 온보딩 완료 여부를 비동기로 확인
    final onboardingAsync = ref.watch(onboardingDoneProvider);

    return MaterialApp(
      title: 'CAN',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => _MobileViewport(child: child ?? const SizedBox.shrink()),
      home: authAsync.when(
        data: (user) {
          if (user == null) return const LoginScreen();
          return onboardingAsync.when(
            data: (done) => done ? const AppShell() : const OnboardingScreen(),
            loading: () => const _SplashScreen(),
            error: (_, __) => const AppShell(),
          );
        },
        loading: () => const _SplashScreen(),
        error: (_, __) => const LoginScreen(),
      ),
    );
  }
}

class _MobileViewport extends StatelessWidget {
  const _MobileViewport({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return ColoredBox(
      color: const Color(0xFFF2F4F8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 스플래시 (온보딩 로딩 중 표시)
// ---------------------------------------------------------------------------
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}