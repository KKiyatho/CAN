import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/i18n.dart';
import '../core/theme/theme_notifier.dart';
import '../features/home/home_screen.dart';
import '../features/search/search_screen.dart';
import '../features/community/community_screen.dart';
import '../features/alarm/alarm_screen.dart';
import '../features/wallpaper/wallpaper_screen.dart';

// 현재 선택된 탭 인덱스 (검색 탭 리셋 등 외부에서 참조 가능하도록 공개)
final tabIndexProvider = StateProvider<int>((_) => 0);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(tabIndexProvider);
  final lang = ref.watch(themeNotifierProvider).languageCode;
  final tabs = [
    _TabItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: I18n.t(lang, 'tab.home')),
    _TabItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      label: I18n.t(lang, 'tab.search')),
    _TabItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: I18n.t(lang, 'tab.community')),
    _TabItem(
      icon: Icons.alarm_outlined,
      activeIcon: Icons.alarm,
      label: I18n.t(lang, 'tab.alarm')),
    _TabItem(
      icon: Icons.wallpaper_outlined,
      activeIcon: Icons.wallpaper,
      label: I18n.t(lang, 'tab.wallpaper')),
  ];

    return Scaffold(
      body: IndexedStack(
        // IndexedStack: 탭 전환 시 상태(스크롤, 입력값 등) 유지
        index: currentIndex,
        children: const [
          HomeScreen(),
          SearchScreen(),
          CommunityScreen(),
          AlarmScreen(),
          WallpaperScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) =>
            ref.read(tabIndexProvider.notifier).state = i,
        destinations: tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.activeIcon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem(
      {required this.icon, required this.activeIcon, required this.label});
}
