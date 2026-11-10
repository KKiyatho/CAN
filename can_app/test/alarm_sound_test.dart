import 'package:can_app/features/alarm/alarm_sound_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('소리 활성화 버튼은 알람 대기 중에도 확인음을 재생한다', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final sound = AlarmSound();
    addTearDown(sound.dispose);
    await sound.activate();
    expect(calls.single.method, 'SystemSound.play');
    expect(calls.single.arguments, 'SystemSoundType.alert');
  });
}
