import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../../core/theme/theme_notifier.dart';
import '../../shared/widgets/quote_card.dart';
import '../../shared/widgets/state_views.dart';
import 'home_notifier.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeNotifierProvider);
    final themeState = ref.watch(themeNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CAN',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        centerTitle: false,
        actions: [
          // 다크모드 토글
          IconButton(
            tooltip: '다크/라이트 모드',
            icon: Icon(
              themeState.isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () =>
                ref.read(themeNotifierProvider.notifier).toggleDarkMode(),
          ),
          // 테마 색상 선택
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _showColorPicker(context, ref, themeState),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: themeState.primaryColor,
                child: Icon(Icons.palette,
                    size: 16, color: colorScheme.onPrimary),
              ),
            ),
          ),
        ],
      ),
      body: homeState.quote.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '명언을 불러오지 못했습니다.\n$e',
          onRetry: () =>
              ref.read(homeNotifierProvider.notifier).loadQuote(),
        ),
        data: (quote) => _QuoteBody(
          quote: homeState,
          onRefresh: () =>
              ref.read(homeNotifierProvider.notifier).loadQuote(),
          onBookmark: () =>
              ref.read(homeNotifierProvider.notifier).toggleBookmark(quote.id),
          onShare: () => Share.share(quote.shareText),
        ),
      ),
    );
  }

  void _showColorPicker(
      BuildContext context, WidgetRef ref, ThemeState themeState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('테마 색상',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(kThemeColors.length, (i) {
                final isSelected = themeState.colorIndex == i;
                return GestureDetector(
                  onTap: () {
                    ref
                        .read(themeNotifierProvider.notifier)
                        .setColor(i);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kThemeColors[i],
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3)
                          : null,
                      boxShadow: [
                        BoxShadow(
                            color: kThemeColors[i].withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 22)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 명언 본문 영역
// ---------------------------------------------------------------------------
class _QuoteBody extends ConsumerWidget {
  final HomeState quote;
  final VoidCallback onRefresh;
  final VoidCallback onBookmark;
  final VoidCallback onShare;

  const _QuoteBody({
    required this.quote,
    required this.onRefresh,
    required this.onBookmark,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = quote.quote.value!;
    final isBookmarked = quote.isBookmarked(q.id);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: QuoteCard(quote: q, label: '오늘의 명언'),
              ),
            ),

            // ── 하단 액션 버튼 (Thumb-Zone) ──────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 북마크
                  _ActionButton(
                    icon: isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    label: '저장',
                    color: isBookmarked ? colorScheme.primary : null,
                    onTap: onBookmark,
                  ),
                  // 공유
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: '공유',
                    onTap: onShare,
                  ),
                  // 다른 명언
                  _ActionButton(
                    icon: Icons.refresh,
                    label: '다음 명언',
                    onTap: onRefresh,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 28,
                color: color ?? theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
