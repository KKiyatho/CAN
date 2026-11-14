import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'alarm_model.dart';
import 'alarm_i18n.dart';
import 'alarm_schedule.dart';

const _kAlarmsKey = 'alarms_v1';

class AlarmRepository {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _notificationOpens = StreamController<String>.broadcast();
  Stream<String> get notificationOpens => _notificationOpens.stream;
  String? launchAlarmId;
  Future<void>? _initialization;
  Future<void> _writes = Future.value();

  bool get _native =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    try {
      await (_initialization ??= _initialize());
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    if (!_native) return;
    tz.initializeTimeZones();
    final local = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(local));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => _opened(response.payload),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _opened(launch?.notificationResponse?.payload);
    }
  }

  void _opened(String? payload) {
    if (payload == null) return;
    try {
      final id = (jsonDecode(payload) as Map<String, dynamic>)['alarmId'];
      if (id is String) {
        launchAlarmId = id;
        if (!_notificationOpens.isClosed) _notificationOpens.add(id);
      }
    } on FormatException catch (_) {
      // 이전 버전의 알림은 일반 due 검사로 처리한다.
    }
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<List<AlarmModel>> loadAll() => _serialize(_loadAll);

  Future<List<AlarmModel>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAlarmsKey);
    if (raw == null) return [];
    final alarms = AlarmModel.decodeList(raw);
    var migrated = false;
    final now = DateTime.now();
    final result = alarms.map((alarm) {
      if (alarm.nextOccurrenceMs != null) return alarm;
      migrated = true;
      return alarm.copyWith(
        nextOccurrenceMs: nextAlarmOccurrence(
          alarm,
          now,
        ).millisecondsSinceEpoch,
      );
    }).toList();
    // 구버전은 생성일이 없으므로 이관 시점 이후 첫 회차로 확정한다.
    if (migrated) await _saveAll(result);
    return result;
  }

  Future<void> _saveAll(List<AlarmModel> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_kAlarmsKey, AlarmModel.encodeList(alarms))) {
      throw StateError('alarm_save_failed');
    }
  }

  Future<AlarmModel> create({
    required int hour,
    required int minute,
    List<bool>? repeatDays,
    String? unlockPhrase,
  }) => _serialize(() async {
    final alarms = await _loadAll();
    final alarm = _prepared(
      AlarmModel.create(
        id: _generateId(),
        hour: hour,
        minute: minute,
        repeatDays: repeatDays,
        unlockPhrase: unlockPhrase,
      ),
    );
    await _scheduleNotification(alarm);
    try {
      await _saveAll([...alarms, alarm]);
    } catch (_) {
      await _cancelNotification(alarm.id);
      rethrow;
    }
    return alarm;
  });

  AlarmModel _prepared(AlarmModel alarm) {
    if (alarm.hour < 0 ||
        alarm.hour > 23 ||
        alarm.minute < 0 ||
        alarm.minute > 59 ||
        alarm.repeatDays.length != 7 ||
        alarm.unlockPhrase.trim().isEmpty) {
      throw ArgumentError('invalid_alarm');
    }
    return alarm.copyWith(
      nextOccurrenceMs: nextAlarmOccurrence(
        alarm,
        DateTime.now(),
      ).millisecondsSinceEpoch,
    );
  }

  Future<void> update(AlarmModel alarm) => _serialize(() async {
    final alarms = await _loadAll();
    final index = alarms.indexWhere((item) => item.id == alarm.id);
    if (index == -1) throw StateError('alarm_not_found');
    final previous = alarms[index];
    final updated = _prepared(alarm);
    await _cancelNotification(alarm.id);
    try {
      if (updated.isActive) await _scheduleNotification(updated);
      alarms[index] = updated;
      await _saveAll(alarms);
    } catch (_) {
      await _cancelNotification(alarm.id);
      if (previous.isActive) await _scheduleNotification(previous);
      rethrow;
    }
  });

  Future<void> delete(String id) => _serialize(() async {
    final alarms = await _loadAll();
    await _cancelNotification(id);
    try {
      await _saveAll(alarms.where((alarm) => alarm.id != id).toList());
    } catch (_) {
      for (final alarm in alarms.where(
        (item) => item.id == id && item.isActive,
      )) {
        await _scheduleNotification(alarm);
      }
      rethrow;
    }
  });

  /// 업그레이드한 알람에도 payload를 붙이고 이전 알림 슬롯을 정리한다.
  Future<void> synchronizeNotifications() => _serialize(() async {
    if (!_native) return;
    for (final alarm in await _loadAll()) {
      await _cancelNotification(alarm.id);
      if (alarm.isActive) await _scheduleNotification(alarm);
    }
  });

  // String.hashCode 대신 프로세스 간 안정적인 FNV-1a 사용.
  int _notifId(String id, int day) {
    var hash = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x0fffffff;
    }
    return hash * 7 + day;
  }

  Future<void> _scheduleNotification(AlarmModel alarm) async {
    if (!_native) return;
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('theme_language_code') ?? 'ko';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'can_alarm',
        AlarmI18n.t(lang, 'alarm.notificationChannel'),
        channelDescription: AlarmI18n.t(lang, 'alarm.notificationDescription'),
        importance: Importance.max,
        priority: Priority.max,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    final repeating = alarm.repeatDays.any((day) => day);
    // 이미 지난 단발은 앱의 영속 대기열이 처리한다. 다음 날로 재예약하지 않는다.
    if (!repeating &&
        alarm.nextOccurrenceMs! <= DateTime.now().millisecondsSinceEpoch) {
      return;
    }
    for (var day = 0; day < (repeating ? 7 : 1); day++) {
      if (repeating && !alarm.repeatDays[day]) continue;
      var scheduled = tz.TZDateTime.from(
        DateTime.fromMillisecondsSinceEpoch(alarm.nextOccurrenceMs!),
        tz.local,
      );
      final now = tz.TZDateTime.now(tz.local);
      while ((repeating && scheduled.weekday != day + 1) ||
          !scheduled.isAfter(now)) {
        scheduled = tz.TZDateTime(
          tz.local,
          scheduled.year,
          scheduled.month,
          scheduled.day + 1,
          alarm.hour,
          alarm.minute,
        );
      }
      await _plugin.zonedSchedule(
        _notifId(alarm.id, day),
        AlarmI18n.t(lang, 'alarm.notificationTitle'),
        alarm.unlockPhrase,
        scheduled,
        details,
        payload: jsonEncode({'alarmId': alarm.id}),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: repeating
            ? DateTimeComponents.dayOfWeekAndTime
            : null,
      );
    }
  }

  Future<void> _cancelNotification(String id) async {
    if (!_native) return;
    await initialize();
    for (var day = 0; day < 7; day++) {
      await _plugin.cancel(_notifId(id, day));
      // 이전 버전에서 예약한 슬롯도 업그레이드 중 중복되지 않도록 취소.
      await _plugin.cancel((id.hashCode.abs() % 14285) * 7 + day);
    }
  }

  void dispose() => unawaited(_notificationOpens.close());

  static String _generateId() {
    final random = Random.secure();
    return List.generate(
      8,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

final alarmRepositoryProvider = Provider<AlarmRepository>((ref) {
  final repository = AlarmRepository();
  ref.onDispose(repository.dispose);
  return repository;
});
