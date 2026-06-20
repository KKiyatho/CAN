import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_shell.dart';
import '../../core/theme/i18n.dart';
import '../../core/theme/theme_notifier.dart';

const _kOnboardingDoneKey = 'onboarding_done';

// ---------------------------------------------------------------------------
// 온보딩 완료 여부 Provider
// ---------------------------------------------------------------------------
final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDoneKey) ?? false;
});

// ---------------------------------------------------------------------------
// OnboardingScreen — 앱 최초 실행 시 테마 색상 선택
// ---------------------------------------------------------------------------
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _selectedIndex = 0;

  Future<void> _complete() async {
    await ref.read(themeNotifierProvider.notifier).setColor(_selectedIndex);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDoneKey, true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(themeNotifierProvider).languageCode;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colorLabels = [
      I18n.t(lang, 'onboarding.colorBlue'),
      I18n.t(lang, 'onboarding.colorPink'),
      I18n.t(lang, 'onboarding.colorOrange'),
      I18n.t(lang, 'onboarding.colorGreen'),
      I18n.t(lang, 'onboarding.colorPurple'),
    ];

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // ── 헤더 ──────────────────────────────────────────────────
              Text(
                'CAN',
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: kThemeColors[_selectedIndex],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                I18n.t(lang, 'onboarding.subtitle'),
                style: textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              // ── 색상 선택 ──────────────────────────────────────────────
              _ColorPicker(
                selectedIndex: _selectedIndex,
                onSelect: (i) => setState(() => _selectedIndex = i),
              ),
              const SizedBox(height: 16),
              // ── 선택된 색상 이름 ───────────────────────────────────────
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    colorLabels[_selectedIndex],
                    key: ValueKey(_selectedIndex),
                    style: textTheme.bodyLarge?.copyWith(
                      color: kThemeColors[_selectedIndex],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // ── 시작 버튼 ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _complete,
                  style: FilledButton.styleFrom(
                    backgroundColor: kThemeColors[_selectedIndex],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    I18n.t(lang, 'onboarding.start'),
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 색상 선택 위젯
// ---------------------------------------------------------------------------
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(kThemeColors.length, (i) {
        final isSelected = i == selectedIndex;
        return GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: isSelected ? 52 : 40,
            height: isSelected ? 52 : 40,
            decoration: BoxDecoration(
              color: kThemeColors[i],
              shape: BoxShape.circle,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: kThemeColors[i].withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
