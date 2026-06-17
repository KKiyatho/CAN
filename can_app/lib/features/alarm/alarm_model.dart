import 'dart:convert';

// ---------------------------------------------------------------------------
// AlarmModel — 알람 데이터 (로컬 SharedPreferences 저장)
// ---------------------------------------------------------------------------
class AlarmModel {
  final String id;
  final int hour;
  final int minute;
  final List<bool> repeatDays; // 7개: [월, 화, 수, 목, 금, 토, 일]
  final String unlockPhrase;   // 타이핑 해제 문구
  final bool isActive;

  const AlarmModel({
    required this.id,
    required this.hour,
    required this.minute,
    required this.repeatDays,
    required this.unlockPhrase,
    this.isActive = true,
  });

  factory AlarmModel.create({
    required String id,
    required int hour,
    required int minute,
    List<bool>? repeatDays,
    String? unlockPhrase,
  }) =>
      AlarmModel(
        id: id,
        hour: hour,
        minute: minute,
        repeatDays: repeatDays ?? List.filled(7, false),
        unlockPhrase: unlockPhrase ?? '나는 할 수 있다',
        isActive: true,
      );

  AlarmModel copyWith({
    int? hour,
    int? minute,
    List<bool>? repeatDays,
    String? unlockPhrase,
    bool? isActive,
  }) =>
      AlarmModel(
        id: id,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        repeatDays: repeatDays ?? List.from(this.repeatDays),
        unlockPhrase: unlockPhrase ?? this.unlockPhrase,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'repeatDays': repeatDays,
        'unlockPhrase': unlockPhrase,
        'isActive': isActive,
      };

  factory AlarmModel.fromJson(Map<String, dynamic> json) => AlarmModel(
        id: json['id'] as String,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        repeatDays: (json['repeatDays'] as List).cast<bool>(),
        unlockPhrase: json['unlockPhrase'] as String,
        isActive: json['isActive'] as bool,
      );

  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  String get repeatLabel {
    final active = [
      for (int i = 0; i < 7; i++)
        if (repeatDays[i]) dayLabels[i],
    ];
    if (active.isEmpty) return '반복 없음';
    if (active.length == 7) return '매일';
    if (active.length == 5 && !repeatDays[5] && !repeatDays[6]) {
      return '평일';
    }
    return active.join(', ');
  }

  static String encodeList(List<AlarmModel> list) =>
      jsonEncode(list.map((a) => a.toJson()).toList());

  static List<AlarmModel> decodeList(String raw) =>
      (jsonDecode(raw) as List)
          .map((e) => AlarmModel.fromJson(e as Map<String, dynamic>))
          .toList();
}
