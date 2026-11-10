import 'dart:async';

import 'package:can_app/core/theme/i18n.dart';
import 'package:can_app/core/theme/theme_notifier.dart';
import 'package:can_app/features/alarm/alarm_i18n.dart';
import 'package:can_app/features/alarm/alarm_model.dart';
import 'package:can_app/features/alarm/alarm_notifier.dart';
import 'package:can_app/features/alarm/alarm_runtime.dart';
import 'package:can_app/features/alarm/alarm_screen.dart';
import 'package:can_app/features/alarm/alarm_unlock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EnglishTheme extends ThemeNotifier {
  @override
  ThemeState build() => const ThemeState(
    colorIndex: 0,
    isDark: false,
    languageCode: 'en',
  );
}

const _authoredPhrase = '  나만의 문구 Keep exactly  ';

class _Alarms extends AlarmNotifier {
  @override
  List<AlarmModel> build() {
    ready = Future.value();
    return [
      AlarmModel(
        id: 'authored',
        hour: 8,
        minute: 30,
        repeatDays: [true, false, false, false, false, false, true],
        unlockPhrase: _authoredPhrase,
      ),
    ];
  }
}

class _SoundController extends AlarmRuntimeController {
  Completer<void>? activation;

  @override
  Future<void> activateSound() => activation!.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (_) async => <int, int>{17: 1});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, null);
  });

  test('feature translations fall back to existing shared I18n', () {
    expect(AlarmI18n.t('en', 'alarm.title'), I18n.t('en', 'alarm.title'));
    expect(AlarmI18n.t('en', 'alarm.notificationTitle'), '🌟 CAN alarm');
    expect(AlarmI18n.t('ko', 'alarm.notificationTitle'), '🌟 CAN 알람');
    expect(AlarmI18n.t('all', 'alarm.day0'), '월');
  });

  testWidgets('English unlock errors retranslate without altering phrase or input',
      (tester) async {
    final container = ProviderContainer(overrides: [
      themeNotifierProvider.overrideWith(_EnglishTheme.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: AlarmUnlockScreen(
          phrase: _authoredPhrase,
          isRinging: true,
          onUnlocked: () async => throw StateError('원본 저장 오류'),
          onActivateSound: () async => throw StateError('원본 소리 오류'),
        ),
      ),
    ));
    expect(find.text(AlarmI18n.t('en', 'alarmUnlock.exactMatch')), findsOneWidget);
    await tester.tap(find.text('Enable sound'));
    await tester.pump();
    expect(find.text(AlarmI18n.t('en', 'alarm.soundFailed')), findsOneWidget);
    expect(find.textContaining('원본 소리 오류'), findsNothing);
    expect(find.text('Retry dismissal'), findsNothing);

    await tester.enterText(find.byType(TextField), _authoredPhrase);
    await tester.pump();
    expect(find.text(AlarmI18n.t('en', 'alarmUnlock.saveFailed')), findsOneWidget);
    expect(find.text('Retry dismissal'), findsOneWidget);
    expect(find.textContaining('원본 저장 오류'), findsNothing);
    await container.read(themeNotifierProvider.notifier).setLanguage('ko');
    await tester.pump();
    expect(find.text(AlarmI18n.t('ko', 'alarmUnlock.saveFailed')), findsOneWidget);
    expect(tester.widget<AlarmUnlockScreen>(find.byType(AlarmUnlockScreen)).phrase,
        _authoredPhrase);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        _authoredPhrase);
  });

  testWidgets('English sound button states and editor preserve authored text',
      (tester) async {
    final sound = _SoundController()..activation = Completer<void>();
    final container = ProviderContainer(overrides: [
      themeNotifierProvider.overrideWith(_EnglishTheme.new),
      alarmNotifierProvider.overrideWith(_Alarms.new),
      alarmRuntimeControllerProvider.overrideWithValue(sound),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AlarmScreen()),
    ));
    await tester.pump();
    expect(find.text('Mon, Sun'), findsOneWidget);
    expect(find.text('Test alarm'), findsOneWidget);
    await tester.tap(find.text(AlarmI18n.t('en', 'alarm.soundEnable')));
    await tester.pump();
    expect(find.text('Enabling sound…'), findsOneWidget);
    sound.activation!.complete();
    // 성공 안내의 진입 애니메이션이 끝나야 표시 시간 타이머가 시작된다.
    await tester.pumpAndSettle();
    expect(find.text(AlarmI18n.t('en', 'alarm.soundEnabled')), findsOneWidget);
    expect(find.text(AlarmI18n.t('en', 'alarm.soundConfirmed')), findsOneWidget);

    sound.activation = Completer<void>();
    await tester.tap(find.text(AlarmI18n.t('en', 'alarm.soundEnabled')));
    await tester.pump();
    sound.activation!.completeError(StateError('원본 활성화 오류'));
    await tester.pump();
    expect(find.text(AlarmI18n.t('en', 'alarm.soundEnable')), findsOneWidget);
    expect(find.textContaining('원본 활성화 오류'), findsNothing);
    // Let the confirmation snackbar finish before checking the queued failure.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text(AlarmI18n.t('en', 'alarm.soundFailed')), findsOneWidget);

    await tester.tap(find.text('08:30'));
    await tester.pumpAndSettle();
    expect(find.text('Mon'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, _authoredPhrase);
    await container.read(themeNotifierProvider.notifier).setLanguage('ko');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        _authoredPhrase);
    expect(container.read(alarmNotifierProvider).single.unlockPhrase,
        _authoredPhrase);
    expect(find.text('월'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));

  testWidgets('runtime load warning is generic and reacts to language changes',
      (tester) async {
    SharedPreferences.setMockInitialValues({'alarms_v1': 'invalid json'});
    final container = ProviderContainer(overrides: [
      themeNotifierProvider.overrideWith(_EnglishTheme.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (_, child) => AlarmRuntime(child: child!),
        home: const Scaffold(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text(AlarmI18n.t('en', 'alarm.loadFailed')), findsOneWidget);
    expect(find.textContaining('FormatException'), findsNothing);
    await container.read(themeNotifierProvider.notifier).setLanguage('ko');
    await tester.pump();
    expect(find.text(AlarmI18n.t('ko', 'alarm.loadFailed')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));
}