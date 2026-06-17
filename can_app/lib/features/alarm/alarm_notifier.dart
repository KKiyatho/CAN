import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alarm_model.dart';
import 'alarm_repository.dart';

// ---------------------------------------------------------------------------
// AlarmNotifier
// ---------------------------------------------------------------------------
class AlarmNotifier extends Notifier<List<AlarmModel>> {
  @override
  List<AlarmModel> build() {
    Future.microtask(() async {
      final alarms = await ref.read(alarmRepositoryProvider).loadAll();
      state = alarms;
    });
    return [];
  }

  Future<void> create({
    required int hour,
    required int minute,
    List<bool>? repeatDays,
    String? unlockPhrase,
  }) async {
    try {
      final alarm = await ref.read(alarmRepositoryProvider).create(
            hour: hour,
            minute: minute,
            repeatDays: repeatDays,
            unlockPhrase: unlockPhrase,
          );
      state = [...state, alarm];
    } catch (e) {
      if (kDebugMode) debugPrint('[Alarm] create 실패: $e');
    }
  }

  Future<void> toggle(String id) async {
    final idx = state.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    final updated = state[idx].copyWith(isActive: !state[idx].isActive);
    final newState = List<AlarmModel>.from(state);
    newState[idx] = updated;
    state = newState;
    await ref.read(alarmRepositoryProvider).update(updated);
  }

  Future<void> update(AlarmModel alarm) async {
    final idx = state.indexWhere((a) => a.id == alarm.id);
    if (idx == -1) return;
    final newState = List<AlarmModel>.from(state);
    newState[idx] = alarm;
    state = newState;
    await ref.read(alarmRepositoryProvider).update(alarm);
  }

  Future<void> delete(String id) async {
    state = state.where((a) => a.id != id).toList();
    await ref.read(alarmRepositoryProvider).delete(id);
  }
}

final alarmNotifierProvider =
    NotifierProvider<AlarmNotifier, List<AlarmModel>>(AlarmNotifier.new);
