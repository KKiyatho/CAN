import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// 앱에서 선택 가능한 테마 색상 5종
// ---------------------------------------------------------------------------
const List<Color> kThemeColors = [
  Color(0xFF5C8DFF), // 파스텔 블루 (기본)
  Color(0xFFFF6F91), // 인디 핑크
  Color(0xFFFFB347), // 옐로우 오렌지
  Color(0xFF6BC46D), // 민트 그린
  Color(0xFFAF7AC5), // 라벤더
];

// SharedPreferences 키
const _kColorIndexKey = 'theme_color_index';
const _kDarkModeKey = 'theme_dark_mode';

// ---------------------------------------------------------------------------
// ThemeState: 현재 테마 색상 인덱스 + 다크모드 여부
// ---------------------------------------------------------------------------
class ThemeState {
  final int colorIndex;
  final bool isDark;

  const ThemeState({required this.colorIndex, required this.isDark});

  Color get primaryColor => kThemeColors[colorIndex];

  ThemeState copyWith({int? colorIndex, bool? isDark}) => ThemeState(
        colorIndex: colorIndex ?? this.colorIndex,
        isDark: isDark ?? this.isDark,
      );
}

// ---------------------------------------------------------------------------
// ThemeNotifier: 색상/다크모드 변경 + SharedPreferences 영속 저장
// ---------------------------------------------------------------------------
class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    // 초기값. 비동기 로드는 loadSaved()로 호출
    return const ThemeState(colorIndex: 0, isDark: false);
  }

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final colorIndex = prefs.getInt(_kColorIndexKey) ?? 0;
    final isDark = prefs.getBool(_kDarkModeKey) ?? false;
    state = ThemeState(colorIndex: colorIndex, isDark: isDark);
  }

  Future<void> setColor(int index) async {
    state = state.copyWith(colorIndex: index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kColorIndexKey, index);
  }

  Future<void> toggleDarkMode() async {
    state = state.copyWith(isDark: !state.isDark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkModeKey, state.isDark);
  }
}

final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);

// ---------------------------------------------------------------------------
// MaterialTheme 빌더: ThemeState → ThemeData
// ---------------------------------------------------------------------------
ThemeData buildThemeData(ThemeState themeState) {
  final seed = themeState.primaryColor;
  final brightness =
      themeState.isDark ? Brightness.dark : Brightness.light;

  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: seed,
    brightness: brightness,
    fontFamily: 'NotoSansKR', // assets/fonts가 없으면 기본 폰트로 폴백됨
  );
}
