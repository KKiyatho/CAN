import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class AlarmSound {
  web.AudioContext? _context;
  Timer? _timer;
  bool _ringing = false;

  /// 반드시 버튼/포인터 이벤트에서 첫 await 전에 호출한다.
  Future<void> activate() async {
    final context = _context == null || _context!.state == 'closed'
        ? (_context = web.AudioContext())
        : _context!;
    // resume과 첫 음원 시작을 모두 클릭 스택에서 실행한다(iOS 포함).
    final resumed = context.resume().toDart;
    _playTone(context);
    try {
      await resumed.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      throw StateError('alarm_sound_blocked');
    }
    if (context.state != 'running') {
      throw StateError('alarm_sound_not_running');
    }
    // 확인음은 알람을 예약하거나 해제하지 않는다.
    _playTone(context);
  }

  Future<void> start() async {
    if (_ringing) return;
    _ringing = true;
    _beep();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _beep());
  }

  void _beep() {
    final context = _context;
    if (!_ringing || context == null || context.state != 'running') return;
    _playTone(context);
  }

  void _playTone(web.AudioContext context) {
    final oscillator = context.createOscillator();
    final gain = context.createGain();
    oscillator.frequency.value = 880;
    gain.gain.setValueAtTime(0.0001, context.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.15, context.currentTime + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + 0.4);
    oscillator.connect(gain);
    gain.connect(context.destination);
    oscillator.onended = ((web.Event _) {
      oscillator.disconnect();
      gain.disconnect();
    }).toJS;
    oscillator.start();
    oscillator.stop(context.currentTime + 0.45);
  }

  void stop() {
    _ringing = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    final context = _context;
    if (context != null) unawaited(context.close().toDart);
    _context = null;
  }
}
