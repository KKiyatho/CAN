import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/home/home_screen.dart';
import '../features/search/search_screen.dart';
import '../features/community/community_screen.dart';
import '../features/alarm/alarm_screen.dart';
import '../features/wallpaper/wallpaper_screen.dart';

// 현재 선택된 탭 인덱스
final _tabIndexProvider = StateProvider<int>((_) => 0);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '홈'),
    _TabItem(
        icon: Icons.search_outlined,
        activeIcon: Icons.search,
        label: '검색/추천'),
    _TabItem(
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        label: '커뮤니티'),
    _TabItem(
        icon: Icons.alarm_outlined,
        activeIcon: Icons.alarm,
        label: '알람'),
    _TabItem(
        icon: Icons.wallpaper_outlined,
        activeIcon: Icons.wallpaper,
        label: '배경화면'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(_tabIndexProvider);

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
            ref.read(_tabIndexProvider.notifier).state = i,
        destinations: _tabs
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
