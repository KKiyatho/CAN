import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../core/theme/theme_notifier.dart';
import '../../features/home/quote_repository.dart';
import '../../shared/models/quote.dart';

// ---------------------------------------------------------------------------
// 배경화면 화면 상태
// ---------------------------------------------------------------------------
class _WallpaperState {
  final Quote? quote;
  final int bgColorIndex;
  final int fontSizeStep; // 0=소, 1=중, 2=대
  final bool isLoading;
  final bool isSaving;

  const _WallpaperState({
    this.quote,
    this.bgColorIndex = 0,
    this.fontSizeStep = 1,
    this.isLoading = false,
    this.isSaving = false,
  });

  _WallpaperState copyWith({
    Quote? quote,
    int? bgColorIndex,
    int? fontSizeStep,
    bool? isLoading,
    bool? isSaving,
  }) =>
      _WallpaperState(
        quote: quote ?? this.quote,
        bgColorIndex: bgColorIndex ?? this.bgColorIndex,
        fontSizeStep: fontSizeStep ?? this.fontSizeStep,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
      );
}

// 배경색 팔레트
const _kBgColors = [
  Color(0xFF1A1A2E), // 다크 네이비
  Color(0xFF16213E), // 다크 블루
  Color(0xFF0F3460), // 미드나잇 블루
  Color(0xFF533483), // 딥 퍼플
  Color(0xFF1B4332), // 포레스트 그린
  Color(0xFF7B2D00), // 딥 오렌지
  Color(0xFF2D2D2D), // 차콜
  Color(0xFFFFFFFF), // 화이트
];

const _kFontSizes = [18.0, 24.0, 32.0]; // 소, 중, 대

// ---------------------------------------------------------------------------
// WallpaperScreen
// ---------------------------------------------------------------------------
class WallpaperScreen extends ConsumerStatefulWidget {
  const WallpaperScreen({super.key});

  @override
  ConsumerState<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends ConsumerState<WallpaperScreen> {
  _WallpaperState _ws = const _WallpaperState(isLoading: true);
  final _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRandomQuote());
  }

  Future<void> _loadRandomQuote() async {
    setState(() => _ws = _ws.copyWith(isLoading: true));
    try {
      final quote =
          await ref.read(quoteRepositoryProvider).fetchFeaturedQuote();
      setState(() => _ws = _ws.copyWith(quote: quote, isLoading: false));
    } catch (_) {
      setState(() => _ws = _ws.copyWith(isLoading: false));
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _ws = _ws.copyWith(isSaving: true));
    try {
      // 권한 확인
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        await Gal.requestAccess(toAlbum: true);
      }

      // RepaintBoundary → PNG bytes
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      await Gal.putImageBytes(byteData.buffer.asUint8List(), name: 'can_wallpaper');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('갤러리에 저장됐습니다!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장에 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _ws = _ws.copyWith(isSaving: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeNotifierProvider);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('배경화면'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: _loadRandomQuote,
            tooltip: '다른 명언',
          ),
        ],
      ),
      body: _ws.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── 미리보기 캔버스 ───────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: _WallpaperCanvas(
                          quote: _ws.quote,
                          bgColor: _kBgColors[_ws.bgColorIndex],
                          fontSize: _kFontSizes[_ws.fontSizeStep],
                          accentColor: themeState.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
                // ── 컨트롤 패널 ──────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 배경색 선택 ────────────────────────────────────
                      Text('배경색', style: textTheme.labelMedium),
                      const SizedBox(height: 8),
                      _BgColorPicker(
                        selectedIndex: _ws.bgColorIndex,
                        onSelect: (i) =>
                            setState(() => _ws = _ws.copyWith(bgColorIndex: i)),
                      ),
                      const SizedBox(height: 16),
                      // ── 폰트 크기 ─────────────────────────────────────
                      Row(
                        children: [
                          Text('글자 크기', style: textTheme.labelMedium),
                          const Spacer(),
                          _FontSizeToggle(
                            step: _ws.fontSizeStep,
                            onStep: (s) =>
                                setState(() => _ws = _ws.copyWith(fontSizeStep: s)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // ── 저장 버튼 ─────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _ws.isSaving ? null : _saveToGallery,
                          icon: _ws.isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.download_outlined),
                          label: Text(_ws.isSaving ? '저장 중...' : '갤러리에 저장'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// 배경화면 캔버스 (RepaintBoundary 내부)
// ---------------------------------------------------------------------------
class _WallpaperCanvas extends StatelessWidget {
  const _WallpaperCanvas({
    required this.quote,
    required this.bgColor,
    required this.fontSize,
    required this.accentColor,
  });
  final Quote? quote;
  final Color bgColor;
  final double fontSize;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isLight = bgColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;
    final subtextColor = isLight
        ? Colors.black.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 로고
          Text(
            'CAN',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: accentColor,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 48),
          // 명언
          if (quote != null) ...[
            Text(
              '"${quote!.content}"',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '— ${quote!.author}',
              style: TextStyle(
                fontSize: fontSize * 0.7,
                color: subtextColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            Text(
              '명언을 불러오는 중...',
              style: TextStyle(color: subtextColor),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 배경색 선택 위젯
// ---------------------------------------------------------------------------
class _BgColorPicker extends StatelessWidget {
  const _BgColorPicker({required this.selectedIndex, required this.onSelect});
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_kBgColors.length, (i) {
        final isSelected = i == selectedIndex;
        return GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 8),
            width: isSelected ? 36 : 28,
            height: isSelected ? 36 : 28,
            decoration: BoxDecoration(
              color: _kBgColors[i],
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade400,
                width: isSelected ? 3 : 1,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// 폰트 크기 토글
// ---------------------------------------------------------------------------
class _FontSizeToggle extends StatelessWidget {
  const _FontSizeToggle({required this.step, required this.onStep});
  final int step;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['소', '중', '대'];
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: List.generate(3, (i) {
        final isSelected = i == step;
        return GestureDetector(
          onTap: () => onStep(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? cs.primary : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                color: isSelected ? cs.onPrimary : cs.onSurface,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        );
      }),
    );
  }
}
