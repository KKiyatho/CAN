import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../../core/theme/i18n.dart';
import '../../core/theme/theme_notifier.dart';
import '../../shared/widgets/quote_card.dart';
import '../../shared/widgets/state_views.dart';
import '../search/search_notifier.dart';
import 'home_notifier.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeNotifierProvider);
    final themeState = ref.watch(themeNotifierProvider);
    final lang = themeState.languageCode;
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
            tooltip: I18n.t(lang, 'home.darkModeTooltip'),
            icon: Icon(
              themeState.isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () =>
                ref.read(themeNotifierProvider.notifier).toggleDarkMode(),
          ),
          // 언어 선택
          IconButton(
            tooltip: I18n.t(lang, 'home.languageTooltip'),
            icon: const Icon(Icons.translate),
            onPressed: () => _showLanguagePicker(context, ref, themeState),
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
          message: '${I18n.t(lang, 'home.loadError')}\n$e',
          onRetry: () =>
              ref.read(homeNotifierProvider.notifier).loadQuote(),
        ),
        data: (quote) => _QuoteBody(
          quote: homeState,
          onRefresh: () =>
              ref.read(homeNotifierProvider.notifier).loadQuote(),
          onBookmark: () =>
              ref.read(homeNotifierProvider.notifier).toggleBookmark(quote.id),
          onLike: () =>
              ref.read(homeNotifierProvider.notifier).toggleLike(quote.id),
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
            Text(I18n.t(themeState.languageCode, 'home.themeTitle'),
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

  void _showLanguagePicker(
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
            Text(I18n.t(themeState.languageCode, 'home.languageTitle'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 16),
            ...kLanguageOptions.map((opt) {
              final isSelected = themeState.languageCode == opt.code;
              return ListTile(
                title: Text(opt.label),
                trailing: isSelected
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () async {
                  await ref
                      .read(themeNotifierProvider.notifier)
                      .setLanguage(opt.code);
                  // 언어 변경 후 명언 새로 로드 + 검색 결과 초기화
                  ref.read(homeNotifierProvider.notifier).loadQuote();
                  ref.read(searchNotifierProvider.notifier).clearSearch();
                  if (context.mounted) Navigator.pop(context);
                },
              );
            }),
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
  final VoidCallback onLike;
  final VoidCallback onShare;

  const _QuoteBody({
    required this.quote,
    required this.onRefresh,
    required this.onBookmark,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = quote.quote.value!;
    final isBookmarked = quote.isBookmarked(q.id);
    final isLiked = quote.isLiked(q.id);
    final colorScheme = Theme.of(context).colorScheme;
    final lang = ref.watch(themeNotifierProvider).languageCode;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: QuoteCard(
                    quote: q, label: I18n.t(lang, 'home.todayQuote')),
              ),
            ),

            // ── 하단 액션 버튼 (Thumb-Zone) ──────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 좋아요
                  _ActionButton(
                    icon: isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: I18n.t(lang, 'home.like'),
                    color: isLiked ? Colors.redAccent : null,
                    onTap: onLike,
                  ),
                  // 북마크
                  _ActionButton(
                    icon: isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    label: I18n.t(lang, 'home.save'),
                    color: isBookmarked ? colorScheme.primary : null,
                    onTap: onBookmark,
                  ),
                  // 공유
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: I18n.t(lang, 'home.share'),
                    onTap: onShare,
                  ),
                  // 다른 명언
                  _ActionButton(
                    icon: Icons.refresh,
                    label: I18n.t(lang, 'home.nextQuote'),
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
