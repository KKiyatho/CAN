import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show GestureBinding, PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/i18n.dart';
import '../../core/theme/theme_notifier.dart';

import 'alarm_model.dart';
import 'alarm_i18n.dart';
import 'alarm_notifier.dart';
import 'alarm_runtime.dart';
import 'alarm_unlock_screen.dart';

String _alarmRepeatLabel(List<bool> repeatDays, String lang) {
  final active = <int>[];
  for (var i = 0; i < repeatDays.length; i++) {
    if (repeatDays[i]) active.add(i);
  }
  if (active.isEmpty) return AlarmI18n.t(lang, 'alarm.repeatNone');
  if (active.length == 7) return AlarmI18n.t(lang, 'alarm.repeatDaily');
  final weekdaySet = {0, 1, 2, 3, 4};
  if (active.toSet().containsAll(weekdaySet) && active.length == 5) {
    return AlarmI18n.t(lang, 'alarm.repeatWeekdays');
  }
  return active.map((i) => AlarmI18n.t(lang, 'alarm.day$i')).join(', ');
}

// ---------------------------------------------------------------------------
// AlarmScreen
// ---------------------------------------------------------------------------
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key});

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> {
  bool _activatingSound = false;
  bool _soundEnabled = false;

  Future<void> _activateSound() async {
    if (_activatingSound) return;
    // await 전에 호출해 브라우저의 사용자 클릭 권한을 유지한다.
    final activation = ref.read(alarmRuntimeControllerProvider).activateSound();
    setState(() => _activatingSound = true);
    try {
      await activation;
      if (!mounted) return;
      setState(() => _soundEnabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AlarmI18n.t(
            ref.read(themeNotifierProvider).languageCode,
            'alarm.soundConfirmed',
          )),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _soundEnabled = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AlarmI18n.t(
        ref.read(themeNotifierProvider).languageCode,
        'alarm.soundFailed',
      ))));
    } finally {
      if (mounted) setState(() => _activatingSound = false);
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AlarmI18n.t(
          ref.read(themeNotifierProvider).languageCode,
          'alarm.operationFailed',
        ))));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermission());
  }

  Future<void> _requestPermission() async {
    if (kIsWeb) return; // 웹은 권한 요청 불필요
    await Permission.notification.request();
    // Android 12–32는 정확한 알람을 사용자가 설정에서 허용해야 한다(33+는 자동 허용).
    if (defaultTargetPlatform == TargetPlatform.android &&
        !await Permission.scheduleExactAlarm.isGranted) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  Future<void> _showCreateSheet() async {
    await _openAlarmEditorSheet();
  }

  Future<void> _showEditSheet(AlarmModel alarm) async {
    await _openAlarmEditorSheet(existing: alarm);
  }

  Future<void> _openAlarmEditorSheet({AlarmModel? existing}) async {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: _AlarmEditSheet(existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(themeNotifierProvider).languageCode;
    final alarms = ref.watch(alarmNotifierProvider);
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t(lang, 'alarm.title')),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'alarm_fab',
        tooltip: I18n.t(lang, 'alarm.add'),
        onPressed: _showCreateSheet,
        child: const Icon(Icons.add_alarm_outlined),
      ),
      body: Column(
        children: [
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                AlarmI18n.t(lang, 'alarm.webWarning'),
              ),
            ),
          TextButton.icon(
            onPressed: _activatingSound ? null : _activateSound,
            icon: Icon(
              _soundEnabled ? Icons.volume_up : Icons.volume_up_outlined,
            ),
            label: Text(
                AlarmI18n.t(lang, _activatingSound
                  ? 'alarm.soundActivating'
                  : _soundEnabled
                  ? 'alarm.soundEnabled'
                  : 'alarm.soundEnable'),
            ),
          ),
          Expanded(
            child: alarms.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.alarm_off_outlined,
                          size: 64,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          I18n.t(lang, 'alarm.empty'),
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: alarms.length,
                    itemBuilder: (ctx, i) => _AlarmCard(
                      alarm: alarms[i],
                      lang: lang,
                      onToggle: () => _perform(
                        () => ref
                            .read(alarmNotifierProvider.notifier)
                            .toggle(alarms[i].id),
                      ),
                      onEdit: () => _showEditSheet(alarms[i]),
                      onDelete: () => _perform(
                        () => ref
                            .read(alarmNotifierProvider.notifier)
                            .delete(alarms[i].id),
                      ),
                      onRingTest: () => _perform(
                        () => ref
                            .read(alarmRuntimeControllerProvider)
                            .testAlarm(alarms[i]),
                      ),
                      onUnlockPreview: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AlarmUnlockScreen(phrase: alarms[i].unlockPhrase),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
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
    required this.lang,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onUnlockPreview,
    required this.onRingTest,
  });
  final AlarmModel alarm;
  final String lang;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUnlockPreview;
  final VoidCallback onRingTest;

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
                      _alarmRepeatLabel(alarm.repeatDays, lang),
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: onUnlockPreview,
                      child: Row(
                        children: [
                          Icon(
                            Icons.keyboard_outlined,
                            size: 14,
                            color: cs.primary,
                          ),
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
                    TextButton.icon(
                      onPressed: onRingTest,
                      icon: const Icon(Icons.alarm_on_outlined, size: 18),
                      label: Text(AlarmI18n.t(lang, 'alarm.ringTest')),
                    ),
                  ],
                ),
              ),
              // 삭제 + 토글
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: AlarmI18n.t(lang, 'alarm.delete'),
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
  bool _saving = false;

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
    final lang = ref.read(themeNotifierProvider).languageCode;
    _phraseController = TextEditingController(
      text: widget.existing?.unlockPhrase ?? I18n.t(lang, 'alarm.unlockHint'),
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

  /// 휠 항목 공통 래퍼: 마우스 휠은 정확히 1칸씩, 탭하면 해당 숫자로 이동.
  /// (기본 동작은 휠 델타(~100px)가 2칸 이상으로 환산되어 건너뛰는 문제가 있음)
  Widget _wheelCell(
    FixedExtentScrollController controller,
    int index,
    int count,
    Widget child,
  ) {
    const duration = Duration(milliseconds: 120);
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        // 가장 안쪽 리스너가 먼저 등록되므로 기본 스크롤 처리보다 우선한다.
        GestureBinding.instance.pointerSignalResolver.register(event, (e) {
          final dy = (e as PointerScrollEvent).scrollDelta.dy;
          if (dy == 0) return;
          final next = (controller.selectedItem + (dy > 0 ? 1 : -1)).clamp(
            0,
            count - 1,
          );
          controller.animateToItem(
            next,
            duration: duration,
            curve: Curves.easeOut,
          );
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.animateToItem(
          index,
          duration: duration,
          curve: Curves.easeOut,
        ),
        child: child,
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    // 사용자 클릭 스택 안에서 오디오 활성화를 먼저 시작한다.
    final activation = ref.read(alarmRuntimeControllerProvider).activateSound();
    setState(() => _saving = true);
    try {
      await activation;
      // 빈 문구만 기본값으로 대체한다. 길이는 입력창에서 제한한다.
      final lang = ref.read(themeNotifierProvider).languageCode;
      String phrase = _phraseController.text;
      // Preserve authored text (including spaces) across edits and language changes.
      if (phrase.trim().isEmpty) phrase = I18n.t(lang, 'alarm.unlockHint');

      final notifier = ref.read(alarmNotifierProvider.notifier);
      if (widget.existing != null) {
        await notifier.update(
          widget.existing!.copyWith(
            hour: _hour,
            minute: _minute,
            repeatDays: _repeatDays,
            unlockPhrase: phrase,
          ),
        );
      } else {
        await notifier.create(
          hour: _hour,
          minute: _minute,
          repeatDays: _repeatDays,
          unlockPhrase: phrase,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AlarmI18n.t(
          ref.read(themeNotifierProvider).languageCode,
          'alarm.saveFailed',
        ))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(themeNotifierProvider).languageCode;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: math.max(0.0, MediaQuery.of(context).viewInsets.bottom) + 24,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
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
            Text(I18n.t(lang, 'alarm.time'), style: textTheme.labelMedium),
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
                            builder: (_, i) => _wheelCell(
                              _hourController,
                              i,
                              24,
                              Center(
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
                            builder: (_, i) => _wheelCell(
                              _minuteController,
                              i,
                              60,
                              Center(
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
            Text(I18n.t(lang, 'alarm.repeat'), style: textTheme.labelMedium),
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
                      color: _repeatDays[i]
                          ? cs.primary
                          : cs.surfaceContainerHighest,
                    ),
                    child: Center(
                      child: Text(
                        AlarmI18n.t(lang, 'alarm.day$i'),
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
            Text(
              I18n.t(lang, 'alarm.unlockPhrase'),
              style: textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phraseController,
              maxLength: 30,
              decoration: InputDecoration(
                hintText: I18n.t(lang, 'alarm.unlockHint'),
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
                onPressed: _saving ? null : _save,
                child: Text(
                    _saving
                      ? AlarmI18n.t(lang, 'alarm.saving')
                      : widget.existing != null
                      ? I18n.t(lang, 'alarm.edit')
                      : I18n.t(lang, 'alarm.add'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
