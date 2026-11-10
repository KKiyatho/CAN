import 'dart:async';
import 'package:flutter/services.dart';

class AlarmSound {
  Timer? _timer;
  Future<void> activate() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      throw StateError('alarm_sound_activation_failed');
    }
  }

  Future<void> start() async {
    if (_timer != null) return;
    unawaited(_beep());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _beep());
  }

  Future<void> _beep() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } on PlatformException catch (_) {
      // 기기 음소거/시스템 설정에 따라 시스템 경고음은 들리지 않을 수 있다.
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();
}
