import 'package:flutter/material.dart';
import '../../core/theme/i18n.dart';
import '../../core/theme/theme_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// AlarmUnlockScreen — 명언 타이핑으로 알람 해제
// ---------------------------------------------------------------------------
class AlarmUnlockScreen extends ConsumerStatefulWidget {
  const AlarmUnlockScreen({super.key, required this.phrase});
  final String phrase;

  @override
  ConsumerState<AlarmUnlockScreen> createState() => _AlarmUnlockScreenState();
}

class _AlarmUnlockScreenState extends ConsumerState<AlarmUnlockScreen> {
  final _controller = TextEditingController();
  bool _unlocked = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (value == widget.phrase) {
      setState(() => _unlocked = true);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(themeNotifierProvider).languageCode;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final typed = _controller.text;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 아이콘 & 안내 ─────────────────────────────────────────────
              Icon(
                _unlocked ? Icons.check_circle : Icons.alarm,
                size: 56,
                color: _unlocked ? cs.primary : cs.onSurface,
              ),
              const SizedBox(height: 24),
              Text(
                I18n.t(lang, 'alarmUnlock.guide'),
                style: textTheme.titleLarge?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 32),
              // ── 타겟 문구 ─────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.phrase,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // ── 입력창 ────────────────────────────────────────────────────
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: null,
                onChanged: _onChanged,
                style: textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: I18n.t(lang, 'alarmUnlock.hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _unlocked
                      ? Icon(Icons.check, color: cs.primary)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              // ── 진행 표시 ─────────────────────────────────────────────────
              _TypingProgress(typed: typed, phrase: widget.phrase),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 타이핑 진행도 위젯 (글자별 색상 표시)
// ---------------------------------------------------------------------------
class _TypingProgress extends StatelessWidget {
  const _TypingProgress({required this.typed, required this.phrase});
  final String typed;
  final String phrase;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RichText(
      text: TextSpan(
        children: List.generate(phrase.length, (i) {
          final Color color;
          if (i < typed.length) {
            color = typed[i] == phrase[i] ? cs.primary : cs.error;
          } else {
            color = cs.onSurfaceVariant.withValues(alpha: 0.4);
          }
          return TextSpan(
            text: phrase[i],
            style: TextStyle(
              fontSize: 18,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          );
        }),
      ),
    );
  }
}
