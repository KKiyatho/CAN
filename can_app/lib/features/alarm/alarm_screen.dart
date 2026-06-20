import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'alarm_model.dart';
import 'alarm_notifier.dart';
import 'alarm_unlock_screen.dart';

// ---------------------------------------------------------------------------
// AlarmScreen
// ---------------------------------------------------------------------------
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key});

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermission());
  }

  Future<void> _requestPermission() async {
    if (kIsWeb) return; // 웹은 권한 요청 불필요
    await Permission.notification.request();
  }

  Future<void> _showCreateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AlarmEditSheet(),
    );
  }

  Future<void> _showEditSheet(AlarmModel alarm) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AlarmEditSheet(existing: alarm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alarms = ref.watch(alarmNotifierProvider);
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('알람'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'alarm_fab',
        onPressed: _showCreateSheet,
        child: const Icon(Icons.add_alarm_outlined),
      ),
      body: alarms.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alarm_off_outlined,
                      size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    '알람이 없습니다.\n+ 버튼으로 추가하세요.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: alarms.length,
              itemBuilder: (ctx, i) => _AlarmCard(
                alarm: alarms[i],
                onToggle: () =>
                    ref.read(alarmNotifierProvider.notifier).toggle(alarms[i].id),
                onEdit: () => _showEditSheet(alarms[i]),
                onDelete: () =>
                    ref.read(alarmNotifierProvider.notifier).delete(alarms[i].id),
                onUnlockPreview: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AlarmUnlockScreen(phrase: alarms[i].unlockPhrase),
                  ),
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// 알람 카드
// ---------------------------------------------------------------------------
class _AlarmCard extends StatelessWidget {
  const _AlarmCard({
    required this.alarm,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onUnlockPreview,
  });
  final AlarmModel alarm;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUnlockPreview;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // 시간 표시
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alarm.timeLabel,
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: alarm.isActive
                            ? cs.onSurface
                            : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alarm.repeatLabel,
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: onUnlockPreview,
                      child: Row(
                        children: [
                          Icon(Icons.keyboard_outlined,
                              size: 14, color: cs.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              alarm.unlockPhrase,
                              style: textTheme.labelSmall?.copyWith(
                                color: cs.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 삭제 + 토글
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                    color: cs.onSurfaceVariant,
                    iconSize: 20,
                  ),
                  Switch(value: alarm.isActive, onChanged: (_) => onToggle()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 알람 생성/수정 바텀 시트
// ---------------------------------------------------------------------------
class _AlarmEditSheet extends ConsumerStatefulWidget {
  const _AlarmEditSheet({this.existing});
  final AlarmModel? existing;

  @override
  ConsumerState<_AlarmEditSheet> createState() => _AlarmEditSheetState();
}

class _AlarmEditSheetState extends ConsumerState<_AlarmEditSheet> {
  late int _hour;
  late int _minute;
  late List<bool> _repeatDays;
  late TextEditingController _phraseController;

  // 휠 스크롤 컨트롤러
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.existing?.hour ?? TimeOfDay.now().hour;
    _minute = widget.existing?.minute ?? TimeOfDay.now().minute;
    _repeatDays = widget.existing != null
        ? List.from(widget.existing!.repeatDays)
        : List.filled(7, false);
    _phraseController = TextEditingController(
      text: widget.existing?.unlockPhrase ?? '나는 할 수 있다',
    );
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _phraseController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // 해제 문구 검증: 빈 값이면 기본값, 30자 초과 방어
    String phrase = _phraseController.text.trim();
    if (phrase.isEmpty) phrase = '나는 할 수 있다';
    if (phrase.length > 30) phrase = phrase.substring(0, 30);

    final notifier = ref.read(alarmNotifierProvider.notifier);
    if (widget.existing != null) {
      await notifier.update(widget.existing!.copyWith(
        hour: _hour,
        minute: _minute,
        repeatDays: _repeatDays,
        unlockPhrase: phrase,
      ));
    } else {
      await notifier.create(
        hour: _hour,
        minute: _minute,
        repeatDays: _repeatDays,
        unlockPhrase: phrase,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 핸들 ────────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ── 휠 시간 선택기 ───────────────────────────────────────────────
          Text('시간 설정', style: textTheme.labelMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                // 시간 휠 (0~23)
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 선택 영역 하이라이트
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      ListWheelScrollView.useDelegate(
                        controller: _hourController,
                        itemExtent: 44,
                        diameterRatio: 1.8,
                        perspective: 0.003,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (i) =>
                            setState(() => _hour = i),
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (_, i) => Center(
                            child: Text(
                              i.toString().padLeft(2, '0'),
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _hour == i
                                    ? cs.primary
                                    : cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          childCount: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                // 구분자
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    ':',
                    style: textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
                // 분 휠 (0~59)
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      ListWheelScrollView.useDelegate(
                        controller: _minuteController,
                        itemExtent: 44,
                        diameterRatio: 1.8,
                        perspective: 0.003,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (i) =>
                            setState(() => _minute = i),
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (_, i) => Center(
                            child: Text(
                              i.toString().padLeft(2, '0'),
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _minute == i
                                    ? cs.primary
                                    : cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          childCount: 60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── 반복 요일 ────────────────────────────────────────────────────
          Text('반복', style: textTheme.labelMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              return GestureDetector(
                onTap: () => setState(() => _repeatDays[i] = !_repeatDays[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _repeatDays[i] ? cs.primary : cs.surfaceContainerHighest,
                  ),
                  child: Center(
                    child: Text(
                      AlarmModel.dayLabels[i],
                      style: textTheme.labelMedium?.copyWith(
                        color: _repeatDays[i]
                            ? cs.onPrimary
                            : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // ── 해제 문구 ────────────────────────────────────────────────────
          Text('알람 해제 문구 (직접 입력)', style: textTheme.labelMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _phraseController,
            maxLength: 30,
            decoration: InputDecoration(
              hintText: '나는 할 수 있다',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── 저장 버튼 ────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _save,
              child: Text(widget.existing != null ? '수정하기' : '알람 추가'),
            ),
          ),
        ],
      ),
    );
  }
}
