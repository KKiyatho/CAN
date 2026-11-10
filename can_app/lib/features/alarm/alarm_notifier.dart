import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alarm_model.dart';
import 'alarm_repository.dart';

final alarmLoadErrorProvider = StateProvider<Object?>((ref) => null);

class AlarmNotifier extends Notifier<List<AlarmModel>> {
  late Future<void> ready;

  @override
  List<AlarmModel> build() {
    ready = Future.microtask(() async {
      try {
        state = await ref.read(alarmRepositoryProvider).loadAll();
        ref.read(alarmLoadErrorProvider.notifier).state = null;
      } catch (error) {
        ref.read(alarmLoadErrorProvider.notifier).state = error;
      }
    });
    return [];
  }

  Future<void> reload() async {
    state = await ref.read(alarmRepositoryProvider).loadAll();
    ref.read(alarmLoadErrorProvider.notifier).state = null;
  }

  Future<void> create({
    required int hour,
    required int minute,
    List<bool>? repeatDays,
    String? unlockPhrase,
  }) async {
    await ready;
    await ref
        .read(alarmRepositoryProvider)
        .create(
          hour: hour,
          minute: minute,
          repeatDays: repeatDays,
          unlockPhrase: unlockPhrase,
        );
    await reload();
  }

  Future<void> toggle(String id) async {
    await ready;
    final alarm = state.firstWhere((item) => item.id == id);
    await update(alarm.copyWith(isActive: !alarm.isActive));
  }

  Future<void> update(AlarmModel alarm) async {
    await ready;
    await ref.read(alarmRepositoryProvider).update(alarm);
    await reload();
  }

  Future<void> delete(String id) async {
    await ready;
    await ref.read(alarmRepositoryProvider).delete(id);
    await reload();
  }
}

final alarmNotifierProvider = NotifierProvider<AlarmNotifier, List<AlarmModel>>(
  AlarmNotifier.new,
);
