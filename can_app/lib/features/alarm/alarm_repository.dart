import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'alarm_model.dart';

const _kAlarmsKey = 'alarms_v1';

// ---------------------------------------------------------------------------
// AlarmRepository — 알람 로컬 저장 + 로컬 알림 스케줄링
// ---------------------------------------------------------------------------
class AlarmRepository {
  AlarmRepository() {
    _initTimezone();
    _initNotifications();
  }

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 타임존 초기화 — flutter_timezone으로 디바이스 로컬 시간대 명시 설정
  Future<void> _initTimezone() async {
    tz.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      // 타임존 조회 실패 시 UTC 기본값 유지 (안전한 폴백)
    }
  }

  Future<void> _initNotifications() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────
  Future<List<AlarmModel>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAlarmsKey);
    if (raw == null) return [];
    return AlarmModel.decodeList(raw);
  }

  Future<void> _saveAll(List<AlarmModel> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAlarmsKey, AlarmModel.encodeList(alarms));
  }

  Future<AlarmModel> create({
    required int hour,
    required int minute,
    List<bool>? repeatDays,
    String? unlockPhrase,
  }) async {
    final alarms = await loadAll();
    final alarm = AlarmModel.create(
      id: _generateId(),
      hour: hour,
      minute: minute,
      repeatDays: repeatDays,
      unlockPhrase: unlockPhrase,
    );
    alarms.add(alarm);
    await _saveAll(alarms);
    await _scheduleNotification(alarm);
    return alarm;
  }

  Future<void> update(AlarmModel alarm) async {
    final alarms = await loadAll();
    final idx = alarms.indexWhere((a) => a.id == alarm.id);
    if (idx == -1) return;
    alarms[idx] = alarm;
    await _saveAll(alarms);
    await _cancelNotification(alarm.id);
    if (alarm.isActive) await _scheduleNotification(alarm);
  }

  Future<void> delete(String id) async {
    final alarms = await loadAll();
    alarms.removeWhere((a) => a.id == id);
    await _saveAll(alarms);
    await _cancelNotification(id);
  }

  // ── 알림 스케줄링 ──────────────────────────────────────────────────────────
  //
  // 알림 ID 할당 방식 (충돌 방지):
  //   base = id.hashCode.abs() % 14285        → 0..14284
  //   notifId(dayIdx) = base * 7 + dayIdx     → 0..99994
  // 서로 다른 alarm.id 는 base 값이 달라 dayIdx slot 이 겹치지 않는다.
  // 단발 알람은 dayIdx=0 슬롯만 사용.
  // ─────────────────────────────────────────────────────────────────────────

  int _notifId(String id, int dayIdx) =>
      (id.hashCode.abs() % 14285) * 7 + dayIdx;

  Future<void> _scheduleNotification(AlarmModel alarm) async {
    await _initNotifications();

    const androidDetails = AndroidNotificationDetails(
      'can_alarm',
      'CAN 알람',
      channelDescription: '동기부여 알람',
      importance: Importance.max,
      priority: Priority.max,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final hasRepeat = alarm.repeatDays.any((d) => d);

    if (!hasRepeat) {
      // ── 단발: 오늘 또는 내일 한 번만 ────────────────────────────────────
      final scheduled = _nextOccurrence(alarm.hour, alarm.minute);
      await _plugin.zonedSchedule(
        _notifId(alarm.id, 0),
        '🌟 CAN 알람',
        alarm.unlockPhrase,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } else {
      // ── 반복: 활성 요일마다 독립 알림 스케줄 ───────────────────────────
      // AlarmModel.repeatDays 인덱스: 0=월, 1=화, ..., 6=일
      // DateTime.weekday:            1=월, 2=화, ..., 7=일
      for (int dayIdx = 0; dayIdx < 7; dayIdx++) {
        if (!alarm.repeatDays[dayIdx]) continue;
        final scheduled =
            _nextOccurrenceForWeekday(alarm.hour, alarm.minute, dayIdx);
        await _plugin.zonedSchedule(
          _notifId(alarm.id, dayIdx),
          '🌟 CAN 알람',
          alarm.unlockPhrase,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  /// 오늘 또는 내일의 [hour:minute] TZDateTime 반환
  tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// 특정 요일(dayIdx: 0=월 ~ 6=일)의 다음 [hour:minute] TZDateTime 반환
  tz.TZDateTime _nextOccurrenceForWeekday(int hour, int minute, int dayIdx) {
    final targetWeekday = dayIdx + 1; // DateTime.weekday: 1=월..7=일
    final now = tz.TZDateTime.now(tz.local);
    var candidate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // 해당 요일이면서 미래인 날까지 하루씩 전진
    while (candidate.weekday != targetWeekday || candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  Future<void> _cancelNotification(String id) async {
    await _initNotifications();
    // 단발(dayIdx=0) + 반복(dayIdx=0..6) 슬롯 전부 취소
    for (int i = 0; i < 7; i++) {
      await _plugin.cancel(_notifId(id, i));
    }
  }

  static String _generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(8, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

final alarmRepositoryProvider = Provider<AlarmRepository>(
  (_) => AlarmRepository(),
);
