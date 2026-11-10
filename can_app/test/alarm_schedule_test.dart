import 'package:can_app/features/alarm/alarm_model.dart';
import 'package:can_app/features/alarm/alarm_repository.dart';
import 'package:can_app/features/alarm/alarm_runtime_store.dart';
import 'package:can_app/features/alarm/alarm_schedule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AlarmModel alarm({String id = 'a', List<bool>? days, DateTime? due}) =>
    AlarmModel(
      id: id,
      hour: 8,
      minute: 30,
      repeatDays: days ?? List.filled(7, false),
      unlockPhrase: '나는 할 수 있다',
      nextOccurrenceMs: due?.millisecondsSinceEpoch,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('단발은 오늘 미래 또는 내일이고 동일 시각은 다음 회차', () {
    final model = alarm();
    expect(
      nextAlarmOccurrence(model, DateTime(2026, 11, 9, 8)),
      DateTime(2026, 11, 9, 8, 30),
    );
    expect(
      nextAlarmOccurrence(model, DateTime(2026, 11, 9, 8, 30)),
      DateTime(2026, 11, 10, 8, 30),
    );
    expect(
      nextAlarmOccurrence(model, DateTime(2026, 12, 31, 23)),
      DateTime(2027, 1, 1, 8, 30),
    );
  });

  test('요일 0은 월요일, 6은 일요일이며 주 경계를 넘는다', () {
    final monday = alarm(
      days: [true, false, false, false, false, false, false],
    );
    final sunday = alarm(
      days: [false, false, false, false, false, false, true],
    );
    expect(
      nextAlarmOccurrence(monday, DateTime(2026, 11, 8, 9)),
      DateTime(2026, 11, 9, 8, 30),
    );
    expect(
      nextAlarmOccurrence(monday, DateTime(2026, 11, 9, 9)),
      DateTime(2026, 11, 16, 8, 30),
    );
    expect(
      nextAlarmOccurrence(sunday, DateTime(2026, 11, 9)),
      DateTime(2026, 11, 15, 8, 30),
    );
  });

  test('단발 due 대기열과 acknowledgement는 새로 로드해도 중복되지 않는다', () async {
    final due = DateTime(2026, 11, 9, 8, 30);
    final model = alarm(due: due);
    final store = await AlarmRuntimeStore.load();
    expect(
      store.collectDue([model], due.subtract(const Duration(seconds: 1))),
      isTrue,
    );
    expect(store.queue, isEmpty);
    store.collectDue([model], due);
    expect(store.queue, hasLength(1));
    await store.save();
    final restored = await AlarmRuntimeStore.load();
    restored.collectDue([model], due.add(const Duration(days: 1)));
    expect(restored.queue, hasLength(1));
    restored.acknowledge(restored.queue.first);
    await restored.save();
    final acknowledged = await AlarmRuntimeStore.load();
    acknowledged.collectDue([model], due.add(const Duration(days: 2)));
    expect(acknowledged.queue, isEmpty);
    expect(acknowledged.acknowledged[model.id], due.millisecondsSinceEpoch);
  });

  test('반복은 선택 요일만 발화하고 같은 회차는 재발화하지 않는다', () async {
    final due = DateTime(2026, 11, 9, 8, 30);
    final model = alarm(
      due: due,
      days: [true, false, true, false, false, false, false],
    );
    final store = await AlarmRuntimeStore.load();
    store.collectDue([model], due);
    store.acknowledge(store.queue.first);
    store.collectDue([model], DateTime(2026, 11, 10, 23));
    expect(store.queue, isEmpty);
    store.collectDue([model], DateTime(2026, 11, 11, 8, 30));
    store.collectDue([model], DateTime(2026, 11, 11, 8, 31));
    expect(store.queue, hasLength(1));
    expect(
      store.queue.first.dueMs,
      DateTime(2026, 11, 11, 8, 30).millisecondsSinceEpoch,
    );
  });

  test('동시 알람은 순차 저장되고 테스트는 미래 회차를 소비하지 않는다', () async {
    final due = DateTime(2026, 11, 9, 8, 30);
    final a = alarm(due: due);
    final b = alarm(id: 'b', due: due);
    final store = await AlarmRuntimeStore.load();
    store.enqueueTest(a, due.subtract(const Duration(minutes: 1)));
    store.acknowledge(store.queue.first);
    expect(store.acknowledged, isEmpty);
    store.collectDue([b, a], due);
    expect(store.queue.map((item) => item.alarm.id), ['a', 'b']);
    await store.save();
    final restored = await AlarmRuntimeStore.load();
    restored.acknowledge(restored.queue.first);
    expect(restored.queue.single.alarm.id, 'b');
  });

  test('비활성 알람 제외, 수정한 첫 회차로 커서 재설정', () async {
    final due = DateTime(2026, 11, 9, 8, 30);
    final model = alarm(due: due);
    final store = await AlarmRuntimeStore.load();
    store.collectDue([model.copyWith(isActive: false)], due);
    expect(store.queue, isEmpty);
    store.collectDue([model], due);
    store.acknowledge(store.queue.first);
    final tomorrow = due.add(const Duration(days: 1));
    final updated = model.copyWith(
      nextOccurrenceMs: tomorrow.millisecondsSinceEpoch,
    );
    store.collectDue([updated], tomorrow);
    expect(store.queue.single.dueMs, tomorrow.millisecondsSinceEpoch);
  });

  test('구버전 메타데이터 이관은 재로드 시 바뀌지 않는다', () async {
    SharedPreferences.setMockInitialValues({
      'alarms_v1': AlarmModel.encodeList([alarm()]),
    });
    final repository = AlarmRepository();
    addTearDown(repository.dispose);
    final migrated = (await repository.loadAll()).single;
    expect(migrated.nextOccurrenceMs, isNotNull);
    expect(
      (await repository.loadAll()).single.nextOccurrenceMs,
      migrated.nextOccurrenceMs,
    );
  });
}
