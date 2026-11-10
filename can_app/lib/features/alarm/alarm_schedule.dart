import 'alarm_model.dart';

/// 달력 날짜로 이동해야 DST 전환 시에도 같은 로컬 시각을 유지한다.
/// repeatDays는 0=월요일, 6=일요일이며 기준 시각과 같으면 다음 회차다.
DateTime nextAlarmOccurrence(AlarmModel alarm, DateTime after) {
  for (var offset = 0; offset <= 7; offset++) {
    final candidate = DateTime(
      after.year,
      after.month,
      after.day + offset,
      alarm.hour,
      alarm.minute,
    );
    if (!candidate.isAfter(after)) continue;
    if (!alarm.repeatDays.any((day) => day) ||
        alarm.repeatDays[candidate.weekday - 1]) {
      return candidate;
    }
  }
  throw StateError('alarm_next_occurrence_failed');
}
