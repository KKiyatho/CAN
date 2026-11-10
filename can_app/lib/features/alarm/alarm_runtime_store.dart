import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_model.dart';
import 'alarm_schedule.dart';

class AlarmOccurrence {
  const AlarmOccurrence({
    required this.alarm,
    required this.dueMs,
    this.isTest = false,
  });

  final AlarmModel alarm;
  final int dueMs;
  final bool isTest;
  String get key => '${isTest ? 'test' : 'due'}:${alarm.id}:$dueMs';

  Map<String, dynamic> toJson() => {
    'alarm': alarm.toJson(),
    'dueMs': dueMs,
    'isTest': isTest,
  };

  factory AlarmOccurrence.fromJson(Map<String, dynamic> json) =>
      AlarmOccurrence(
        alarm: AlarmModel.fromJson(json['alarm'] as Map<String, dynamic>),
        dueMs: json['dueMs'] as int,
        isTest: json['isTest'] as bool? ?? false,
      );
}

/// 커서와 대기열을 한 JSON으로 저장한다. 저장 성공 전에는 소리/화면을 시작하지 않는다.
/// 종료 중 놓친 반복 회차는 알람당 한 건으로 합쳐 오래된 알람 폭주를 방지한다.
class AlarmRuntimeStore {
  static const preferencesKey = 'alarm_runtime_v1';
  final List<AlarmOccurrence> queue = [];
  final Map<String, int> acknowledged = {};
  final Map<String, Map<String, dynamic>> _cursors = {};

  static Future<AlarmRuntimeStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final store = AlarmRuntimeStore();
    final raw = prefs.getString(preferencesKey);
    if (raw == null) return store;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    store.queue.addAll(
      (json['queue'] as List).map(
        (row) => AlarmOccurrence.fromJson(row as Map<String, dynamic>),
      ),
    );
    store.acknowledged.addAll(
      (json['acknowledged'] as Map<String, dynamic>).cast<String, int>(),
    );
    for (final entry in (json['cursors'] as Map<String, dynamic>).entries) {
      store._cursors[entry.key] = Map<String, dynamic>.from(entry.value as Map);
    }
    return store;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      preferencesKey,
      jsonEncode({
        'queue': queue.map((item) => item.toJson()).toList(),
        'acknowledged': acknowledged,
        'cursors': _cursors,
      }),
    );
    if (!saved) throw StateError('alarm_runtime_save_failed');
  }

  bool collectDue(List<AlarmModel> alarms, DateTime now) {
    var changed = false;
    final ids = alarms.map((alarm) => alarm.id).toSet();
    final removed = _cursors.keys.where((id) => !ids.contains(id)).toList();
    for (final id in removed) {
      _cursors.remove(id);
      acknowledged.remove(id);
      changed = true;
    }
    for (final alarm in alarms) {
      if (!alarm.isActive || alarm.nextOccurrenceMs == null) continue;
      var cursor = _cursors[alarm.id];
      if (cursor == null || cursor['anchor'] != alarm.nextOccurrenceMs) {
        cursor = {
          'anchor': alarm.nextOccurrenceMs,
          'next': alarm.nextOccurrenceMs,
        };
        _cursors[alarm.id] = cursor;
        changed = true;
      }
      final due = cursor['next'] as int?;
      if (due == null || due > now.millisecondsSinceEpoch) continue;
      final occurrence = AlarmOccurrence(alarm: alarm, dueMs: due);
      if ((acknowledged[alarm.id] ?? -1) < due &&
          !queue.any((item) => item.key == occurrence.key)) {
        queue.add(occurrence);
      }
      cursor['next'] = alarm.repeatDays.any((day) => day)
          ? nextAlarmOccurrence(alarm, now).millisecondsSinceEpoch
          : null;
      changed = true;
    }
    // 동일 시각은 id로 정렬해서 재시작해도 순서가 결정적이다.
    queue.sort((a, b) {
      final time = a.dueMs.compareTo(b.dueMs);
      return time != 0 ? time : a.key.compareTo(b.key);
    });
    return changed;
  }

  void enqueueTest(AlarmModel alarm, DateTime now) {
    var ms = now.millisecondsSinceEpoch;
    while (queue.any((item) => item.key == 'test:${alarm.id}:$ms')) {
      ms++;
    }
    queue.add(AlarmOccurrence(alarm: alarm, dueMs: ms, isTest: true));
  }

  void acknowledge(AlarmOccurrence occurrence) {
    queue.removeWhere((item) => item.key == occurrence.key);
    if (!occurrence.isTest) {
      final previous = acknowledged[occurrence.alarm.id] ?? -1;
      if (occurrence.dueMs > previous) {
        acknowledged[occurrence.alarm.id] = occurrence.dueMs;
      }
    }
  }
}
