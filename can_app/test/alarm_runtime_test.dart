import 'package:can_app/features/alarm/alarm_model.dart';
import 'package:can_app/features/alarm/alarm_notifier.dart';
import 'package:can_app/features/alarm/alarm_runtime.dart';
import 'package:can_app/features/alarm/alarm_runtime_store.dart';
import 'package:can_app/features/alarm/alarm_unlock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    '동시 단발은 전역 화면에서 순차 해제되고 재시작 시 재발화하지 않는다',
    (tester) async {
      final due = DateTime.now().subtract(const Duration(minutes: 1));
      final alarms = [
        for (final id in ['a', 'b'])
          AlarmModel(
            id: id,
            hour: due.hour,
            minute: due.minute,
            repeatDays: List.filled(7, false),
            unlockPhrase: '문구 $id',
            nextOccurrenceMs: due.millisecondsSinceEpoch,
          ),
      ];
      SharedPreferences.setMockInitialValues({
        'alarms_v1': AlarmModel.encodeList(alarms),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      Widget app() => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (_, child) => AlarmRuntime(child: child!),
          home: const Scaffold(body: Text('다른 탭')),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        tester.widget<AlarmUnlockScreen>(find.byType(AlarmUnlockScreen)).phrase,
        '문구 a',
      );
      expect((await AlarmRuntimeStore.load()).queue, hasLength(2));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlarmUnlockScreen), findsOneWidget);

      // 새로고침에 해당하는 위젯 제거/재생성 시 대기 중 첫 알람이 복원된다.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        tester.widget<AlarmUnlockScreen>(find.byType(AlarmUnlockScreen)).phrase,
        '문구 a',
      );
      await tester.enterText(find.byType(TextField), '문구 a');
      await tester.pumpAndSettle();
      expect(
        tester.widget<AlarmUnlockScreen>(find.byType(AlarmUnlockScreen)).phrase,
        '문구 b',
      );
      await tester.enterText(find.byType(TextField), '문구 b');
      await tester.pumpAndSettle();
      expect(find.byType(AlarmUnlockScreen), findsNothing);
      expect(
        container.read(alarmNotifierProvider).every((alarm) => !alarm.isActive),
        isTrue,
      );
      expect((await AlarmRuntimeStore.load()).acknowledged, hasLength(2));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AlarmUnlockScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );

  testWidgets(
    '미리 울려보기는 동일 해제 화면을 사용하지만 미래 단발을 비활성화하지 않는다',
    (tester) async {
      final future = DateTime.now().add(const Duration(hours: 1));
      final alarm = AlarmModel(
        id: 'future',
        hour: future.hour,
        minute: future.minute,
        repeatDays: List.filled(7, false),
        unlockPhrase: '테스트 해제',
        nextOccurrenceMs: future.millisecondsSinceEpoch,
      );
      SharedPreferences.setMockInitialValues({
        'alarms_v1': AlarmModel.encodeList([alarm]),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (_, child) => AlarmRuntime(child: child!),
            home: const Scaffold(body: Text('홈')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await container.read(alarmRuntimeControllerProvider).testAlarm(alarm);
      await tester.pump();
      expect(find.byType(AlarmUnlockScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField), '테스트 해제');
      await tester.pumpAndSettle();
      expect(find.byType(AlarmUnlockScreen), findsNothing);
      expect(container.read(alarmNotifierProvider).single.isActive, isTrue);
      expect(
        container.read(alarmNotifierProvider).single.nextOccurrenceMs,
        alarm.nextOccurrenceMs,
      );
      expect((await AlarmRuntimeStore.load()).acknowledged, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );
}
