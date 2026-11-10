import '../../core/theme/i18n.dart';

/// Feature-owned strings; existing shared translations remain in I18n.
/// Only UI labels are translated, never persisted alarm phrases.
class AlarmI18n {
  AlarmI18n._();

  static String t(String lang, String key) =>
      (lang == 'en' ? _en : _ko)[key] ?? I18n.t(lang, key);

  static const _ko = <String, String>{
    'alarm.repeatNone': '반복 없음',
    'alarm.repeatDaily': '매일',
    'alarm.repeatWeekdays': '평일',
    'alarm.day0': '월',
    'alarm.day1': '화',
    'alarm.day2': '수',
    'alarm.day3': '목',
    'alarm.day4': '금',
    'alarm.day5': '토',
    'alarm.day6': '일',
    'alarm.webWarning': '웹 알람은 이 앱을 열어 둔 동안만 작동합니다. '
        '탭이 정지되거나 브라우저를 닫으면 울림을 보장하지 않습니다. '
        '새로고침 후에는 소리를 다시 활성화해 주세요.',
    'alarm.soundConfirmed': '확인음을 재생했습니다. 안 들리면 미디어 볼륨·탭 음소거를 확인해 주세요.',
    'alarm.soundFailed': '소리 활성화에 실패했습니다. 기기 볼륨과 브라우저 소리 설정을 확인하고 다시 시도해 주세요.',
    'alarm.soundActivating': '소리 활성화 중…',
    'alarm.soundEnabled': '소리 활성화됨 · 확인음 다시 듣기',
    'alarm.soundEnable': '알람 소리 활성화 · 확인음 듣기',
    'alarm.operationFailed': '알람 작업에 실패했습니다. 다시 시도해 주세요.',
    'alarm.saveFailed': '알람 저장에 실패했습니다. 다시 시도해 주세요.',
    'alarm.saving': '저장 중…',
    'alarm.ringTest': '미리 울려보기',
    'alarm.delete': '알람 삭제',
    'alarm.notificationChannel': 'CAN 알람',
    'alarm.notificationDescription': '동기부여 알람',
    'alarm.notificationTitle': '🌟 CAN 알람',
    'alarm.notificationFailed': '네이티브 알림을 초기화하지 못했습니다. 다시 시도해 주세요.',
    'alarm.runtimeFailed': '알람을 처리하지 못했습니다. 다시 시도해 주세요.',
    'alarm.loadFailed': '알람을 불러오지 못했습니다. 다시 시도해 주세요.',
    'alarmUnlock.exactMatch': '문구를 띄어쓰기까지 정확히 입력해야 알람이 멈춥니다.',
    'alarmUnlock.soundEnable': '소리 활성화',
    'alarmUnlock.saveFailed': '해제 저장 실패. 다시 시도해 주세요.',
    'alarmUnlock.retry': '해제 저장 다시 시도',
  };

  static const _en = <String, String>{
    'alarm.repeatNone': 'No repeat',
    'alarm.repeatDaily': 'Every day',
    'alarm.repeatWeekdays': 'Weekdays',
    'alarm.day0': 'Mon',
    'alarm.day1': 'Tue',
    'alarm.day2': 'Wed',
    'alarm.day3': 'Thu',
    'alarm.day4': 'Fri',
    'alarm.day5': 'Sat',
    'alarm.day6': 'Sun',
    'alarm.webWarning': 'Web alarms work only while this app is open. '
        'Alarms may not ring if the tab is suspended or the browser is closed. '
        'Enable sound again after refreshing.',
    'alarm.soundConfirmed': 'Confirmation tone played. If you cannot hear it, check your media volume and whether the tab is muted.',
    'alarm.soundFailed': 'Could not enable sound. Check your device volume and browser sound settings, then try again.',
    'alarm.soundActivating': 'Enabling sound…',
    'alarm.soundEnabled': 'Sound enabled · Play confirmation again',
    'alarm.soundEnable': 'Enable alarm sound · Play confirmation',
    'alarm.operationFailed': 'Could not complete the alarm action. Please try again.',
    'alarm.saveFailed': 'Could not save the alarm. Please try again.',
    'alarm.saving': 'Saving…',
    'alarm.ringTest': 'Test alarm',
    'alarm.delete': 'Delete alarm',
    'alarm.notificationChannel': 'CAN alarms',
    'alarm.notificationDescription': 'Motivational alarms',
    'alarm.notificationTitle': '🌟 CAN alarm',
    'alarm.notificationFailed': 'Could not initialize native notifications. Please try again.',
    'alarm.runtimeFailed': 'Could not process the alarm. Please try again.',
    'alarm.loadFailed': 'Could not load alarms. Please try again.',
    'alarmUnlock.exactMatch': 'Type the phrase exactly, including spaces, to stop the alarm.',
    'alarmUnlock.soundEnable': 'Enable sound',
    'alarmUnlock.saveFailed': 'Could not save the alarm dismissal. Please try again.',
    'alarmUnlock.retry': 'Retry dismissal',
  };
}