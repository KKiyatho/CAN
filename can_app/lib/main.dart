import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_shell.dart';
import 'core/auth/auth_providers.dart';
import 'core/theme/i18n.dart';
import 'core/theme/theme_notifier.dart';
import 'features/alarm/alarm_runtime.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

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

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const ProviderScope(child: CanApp()));
}

class CanApp extends ConsumerWidget {
  const CanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeNotifierProvider);
    final themeData = buildThemeData(themeState);
    final authAsync = ref.watch(authStateProvider);

    // 온보딩 완료 여부를 비동기로 확인
    final onboardingAsync = ref.watch(onboardingDoneProvider);

    return MaterialApp(
      title: 'CAN',
      locale: Locale(themeState.languageCode == 'en' ? 'en' : 'ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: themeData,
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => _MobileViewport(
        child: AlarmRuntime(child: child ?? const SizedBox.shrink()),
      ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // PC 창 높이가 낮아도 휴대폰으로 오인하지 않는다.
        // 실제 모바일 플랫폼은 가로로 돌려도 QR 없이 전체 화면을 사용한다.
        final mobilePlatform =
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS;
        if (constraints.maxWidth <= 600 || mobilePlatform) {
          return child;
        }

        final showQr = constraints.maxWidth >= 900;
        final phone = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430, maxHeight: 960),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: LayoutBuilder(
                builder: (context, phoneConstraints) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: Size(
                      phoneConstraints.maxWidth,
                      phoneConstraints.maxHeight,
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );

        return ColoredBox(
          color: const Color(0xFFF2F4F8),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: showQr
                ? Row(
                    children: [
                      // 양쪽 공간을 동일하게 유지하여 앱 자체는 화면 중앙 정렬.
                      const Expanded(child: SizedBox.shrink()),
                      SizedBox(width: 430, child: Center(child: phone)),
                      const Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 24),
                            child: _DesktopQrCard(),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(child: phone),
          ),
        );
      },
    );
  }
}

class _DesktopQrCard extends ConsumerWidget {
  const _DesktopQrCard();

  static const _appUrl = 'https://canweb125962.z7.web.core.windows.net/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(themeNotifierProvider).languageCode;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            I18n.t(lang, 'qr.title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF202938),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            I18n.t(lang, 'qr.scan'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF5C6678), fontSize: 12),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: '${I18n.t(lang, 'qr.open')}: $_appUrl',
            image: true,
            child: QrImageView(
              data: _appUrl,
              version: QrVersions.auto,
              size: 168,
              padding: const EdgeInsets.all(12),
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            I18n.t(lang, 'qr.install'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF5C6678),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            I18n.t(lang, 'qr.alarmNotice'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF5C6678),
              fontSize: 10,
              height: 1.5,
            ),
          ),
        ],
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
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
