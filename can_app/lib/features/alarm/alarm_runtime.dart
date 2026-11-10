import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_notifier.dart';
import 'alarm_i18n.dart';
import 'alarm_model.dart';
import 'alarm_notifier.dart';
import 'alarm_repository.dart';
import 'alarm_runtime_store.dart';
import 'alarm_sound.dart';
import 'alarm_unlock_screen.dart';

/// 버튼 이벤트에서 동기적으로 activateSound를 호출해 웹 오디오를 해제한다.
class AlarmRuntimeController {
  Future<void> Function()? _activate;
  Future<void> Function(AlarmModel)? _test;

  Future<void> activateSound() {
    final activate = _activate;
    if (activate == null) {
      return Future.error(StateError('alarm_runtime_not_connected'));
    }
    return activate();
  }

  Future<void> testAlarm(AlarmModel alarm) {
    final test = _test;
    if (test == null) {
      return Future.error(StateError('alarm_runtime_not_connected'));
    }
    return test(alarm);
  }
}

final alarmRuntimeControllerProvider = Provider(
  (ref) => AlarmRuntimeController(),
);

/// MaterialApp.builder 안에서 Navigator(child)를 감싸고 ProviderScope 아래에 둔다.
/// 화면/탭 이동과 무관하게 작동하며 웹 종료·정지 상태의 실행은 보장하지 않는다.
class AlarmRuntime extends ConsumerStatefulWidget {
  const AlarmRuntime({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AlarmRuntime> createState() => _AlarmRuntimeState();
}

class _AlarmRuntimeState extends ConsumerState<AlarmRuntime>
    with WidgetsBindingObserver {
  final _sound = AlarmSound();
  AlarmRuntimeStore? _store;
  Timer? _timer;
  StreamSubscription<String>? _notificationSubscription;
  late AlarmRuntimeController _controller;
  late Future<void> Function() _activationHandler;
  late Future<void> Function(AlarmModel) _testHandler;
  Future<void> _operations = Future.value();
  String? _error;
  String? _soundingKey;
  bool _disposed = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ref.read(alarmRuntimeControllerProvider);
    _activationHandler = _sound.activate;
    _controller._activate = _activationHandler;
    _testHandler = (alarm) {
      // 첫 await 전에 AudioContext.resume()을 호출해야 사용자 제스처가 유지된다.
      final activation = _sound.activate();
      return _serialize(() async {
        await activation;
        final store = await AlarmRuntimeStore.load();
        store.enqueueTest(alarm, DateTime.now());
        await store.save();
        _store = store;
        _render();
      });
    };
    _controller._test = _testHandler;
    final repository = ref.read(alarmRepositoryProvider);
    _notificationSubscription = repository.notificationOpens.listen((_) {
      // payload는 초기화/열기 신호일 뿐, 오래된 알림을 새 회차로 강제 발화하지 않는다.
      unawaited(_tick());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) unawaited(_initialize());
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_disposed) unawaited(_tick());
    });
  }

  Future<void> _initialize() async {
    await _tick();
    if (_disposed) return;
    try {
      await ref.read(alarmRepositoryProvider).initialize();
      if (_disposed) return;
      await ref.read(alarmRepositoryProvider).synchronizeNotifications();
      if (!_disposed) await _tick(); // 알림으로 앱을 시작한 경우 포함
    } catch (_) {
      if (!_disposed) setState(() => _error = 'alarm.notificationFailed');
    }
  }

  Future<void> _serialize(Future<void> Function() action) {
    final result = _operations.then((_) async {
      if (_disposed) return;
      try {
        await action();
      } catch (error) {
        // 실패한 스냅샷은 화면에 반영하지 않는다. 다음 작업은 저장 상태로 재시도한다.
        if (!_disposed) setState(() => _error = 'alarm.runtimeFailed');
        rethrow;
      }
    });
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _tick() async {
    if (_checking || _disposed) return;
    _checking = true;
    try {
      await _serialize(() async {
        final notifier = ref.read(alarmNotifierProvider.notifier);
        await notifier.ready;
        if (_disposed) return;
        final store = await AlarmRuntimeStore.load();
        if (ref.read(alarmLoadErrorProvider) == null) {
          final alarms = ref.read(alarmNotifierProvider);
          if (store.collectDue(alarms, DateTime.now())) await store.save();
        }
        _store = store;
        _render();
      });
    } catch (_) {
      // 화면에 오류를 표시하고 다음 tick에서 저장 상태를 다시 로드한다.
    } finally {
      _checking = false;
    }
  }

  void _render() {
    if (_disposed) return;
    final queue = _store!.queue;
    final key = queue.isEmpty ? null : queue.first.key;
    if (key != _soundingKey) {
      // 성공 해제 또는 dispose 외에는 재생을 중단하지 않는다.
      _soundingKey = key;
      if (key != null) unawaited(_sound.start());
    }
    setState(() {});
  }

  Future<void> _unlock(AlarmOccurrence occurrence) => _serialize(() async {
    // 화면의 exact-match 검사 후에만 이 콜백을 호출한다.
    final notifier = ref.read(alarmNotifierProvider.notifier);
    final alarms = ref.read(alarmNotifierProvider);
    final current = alarms.where((alarm) => alarm.id == occurrence.alarm.id);
    if (!occurrence.isTest &&
        !occurrence.alarm.repeatDays.any((day) => day) &&
        current.isNotEmpty &&
        current.first.isActive &&
        current.first.nextOccurrenceMs == occurrence.alarm.nextOccurrenceMs) {
      await notifier.update(current.first.copyWith(isActive: false));
    }
    // 실패 시 현재 화면/소리는 유지되도록 별도 스냅샷에 해제를 반영한다.
    final store = await AlarmRuntimeStore.load();
    store.acknowledge(occurrence);
    await store.save();
    _store = store;
    if (_disposed) return;
    _sound.stop();
    _soundingKey = null;
    _error = null;
    _render();
  });

  @override
  Future<bool> didPopRoute() async => _soundingKey != null;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_tick());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_notificationSubscription?.cancel());
    // 반응형 레이아웃 교체 중 새 Runtime이 먼저 연결됐을 수 있다.
    if (identical(_controller._activate, _activationHandler)) {
      _controller._activate = null;
    }
    if (identical(_controller._test, _testHandler)) {
      _controller._test = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _sound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(themeNotifierProvider).languageCode;
    ref.watch(alarmNotifierProvider);
    final loadError = ref.watch(alarmLoadErrorProvider);
    final queue = _store?.queue ?? <AlarmOccurrence>[];
    final ringing = queue.isNotEmpty;
    final errorKey = loadError == null ? _error : 'alarm.loadFailed';
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: ringing,
          child: ExcludeFocus(
            excluding: ringing,
            child: IgnorePointer(ignoring: ringing, child: widget.child),
          ),
        ),
        if (ringing)
          Positioned.fill(
            child: PopScope(
              canPop: false,
              // builder의 child(Navigator)와 형제이므로 입력 선택용 Overlay도 제공한다.
              child: Overlay.wrap(
                child: AlarmUnlockScreen(
                  key: ValueKey(queue.first.key),
                  phrase: queue.first.alarm.unlockPhrase,
                  isRinging: true,
                  onUnlocked: () => _unlock(queue.first),
                  onActivateSound: _sound.activate,
                ),
              ),
            ),
          ),
        if (errorKey != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top,
            left: 8,
            right: 8,
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  AlarmI18n.t(lang, errorKey),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
