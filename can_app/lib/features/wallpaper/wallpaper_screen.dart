import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/i18n.dart';
import '../../core/theme/theme_notifier.dart';
import '../../features/home/quote_repository.dart';
import '../../shared/models/quote.dart';

// ---------------------------------------------------------------------------
// 배경화면 상태
// ---------------------------------------------------------------------------
class _WallpaperState {
  final Quote? quote;
  final String? customText; // null=명언, non-null=직접 입력
  final int bgGradientIndex;
  final int bgImageIndex;
  final bool useImage;
  final bool isLoading;
  final bool isSaving;

  const _WallpaperState({
    this.quote,
    this.customText,
    this.bgGradientIndex = 0,
    this.bgImageIndex = 0,
    this.useImage = false,
    this.isLoading = false,
    this.isSaving = false,
  });

  _WallpaperState copyWith({
    Quote? quote,
    String? customText,
    bool clearCustomText = false,
    int? bgGradientIndex,
    int? bgImageIndex,
    bool? useImage,
    bool? isLoading,
    bool? isSaving,
  }) =>
      _WallpaperState(
        quote: quote ?? this.quote,
        customText:
            clearCustomText ? null : (customText ?? this.customText),
        bgGradientIndex: bgGradientIndex ?? this.bgGradientIndex,
        bgImageIndex: bgImageIndex ?? this.bgImageIndex,
        useImage: useImage ?? this.useImage,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
      );

  String get displayText {
    if (customText != null && customText!.isNotEmpty) return customText!;
    if (quote != null) return '"${quote!.content}"';
    return '';
  }

  String get authorText {
    if (customText != null && customText!.isNotEmpty) return '';
    if (quote != null) return '— ${quote!.author}';
    return '';
  }
}

// ---------------------------------------------------------------------------
// 배경 그라디언트 12종
// ---------------------------------------------------------------------------
final _kBgGradients = <({String label, LinearGradient gradient})>[
  (label: 'wallpaper.grad.nightBlue', gradient: const LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF2C5364)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
  (label: 'wallpaper.grad.deepPurple', gradient: const LinearGradient(colors: [Color(0xFF16213E), Color(0xFF533483)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
  (label: 'wallpaper.grad.midnight', gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF0F3460)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
  (label: 'wallpaper.grad.forest', gradient: const LinearGradient(colors: [Color(0xFF1B4332), Color(0xFF081C15)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
  (label: 'wallpaper.grad.sunset', gradient: const LinearGradient(colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
  (label: 'wallpaper.grad.flame', gradient: const LinearGradient(colors: [Color(0xFFE0303A), Color(0xFFF7971E)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
  (label: 'wallpaper.grad.dawnPink', gradient: const LinearGradient(colors: [Color(0xFF2D3561), Color(0xFFC05C7E)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
  (label: 'wallpaper.grad.emerald', gradient: const LinearGradient(colors: [Color(0xFF0A3D2E), Color(0xFF11998E)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
  (label: 'wallpaper.grad.goldenHour', gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF8B6914)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
  (label: 'wallpaper.grad.charcoal', gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF3D3D3D)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
  (label: 'wallpaper.grad.indigo', gradient: const LinearGradient(colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
  (label: 'wallpaper.grad.pureWhite', gradient: const LinearGradient(colors: [Color(0xFFF5F5F5), Color(0xFFD0D0D0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
];

// ---------------------------------------------------------------------------
// 배경 이미지 목록
// ---------------------------------------------------------------------------
const _kBgImages = [
  (label: 'wallpaper.img.starryNight', url: 'https://images.unsplash.com/photo-1534796636912-3b95b3ab5986?w=800&q=80&fit=crop'),
  (label: 'wallpaper.img.fogForest', url: 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800&q=80&fit=crop'),
  (label: 'wallpaper.img.seaSunset', url: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80&fit=crop'),
  (label: 'wallpaper.img.mountainTop', url: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&q=80&fit=crop'),
  (label: 'wallpaper.img.cityNight', url: 'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800&q=80&fit=crop'),
  (label: 'wallpaper.img.cherryBlossom', url: 'https://images.unsplash.com/photo-1522383225653-ed111181a951?w=800&q=80&fit=crop'),
];

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
  int _bgTab = 0; // 0=그라디언트, 1=이미지

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadRandomQuote());
  }

  Future<void> _loadRandomQuote() async {
    setState(
        () => _ws = _ws.copyWith(isLoading: true, clearCustomText: true));
    try {
      final quote =
          await ref.read(quoteRepositoryProvider).fetchFeaturedQuote(
                language: ref.read(themeNotifierProvider).languageCode,
              );
      setState(
          () => _ws = _ws.copyWith(quote: quote, isLoading: false));
    } catch (_) {
      setState(() => _ws = _ws.copyWith(isLoading: false));
    }
  }

  void _showCustomInputSheet() {
    final lang = ref.read(themeNotifierProvider).languageCode;
    final controller =
        TextEditingController(text: _ws.customText ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
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
            Text(
              I18n.t(lang, 'wallpaper.customInputTitle'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 150,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                hintText: I18n.t(lang, 'wallpaper.customInputHint'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _ws =
                          _ws.copyWith(clearCustomText: true));
                      Navigator.pop(context);
                    },
                    child: Text(I18n.t(lang, 'wallpaper.restoreQuote')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final text = controller.text.trim();
                      setState(() => _ws = _ws.copyWith(
                            customText:
                                text.isEmpty ? null : text,
                            clearCustomText: text.isEmpty,
                          ));
                      Navigator.pop(context);
                    },
                    child: Text(I18n.t(lang, 'wallpaper.apply')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToGallery() async {
    final lang = ref.read(themeNotifierProvider).languageCode;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(lang, 'wallpaper.webSaveUnsupported'))),
      );
      return;
    }

    setState(() => _ws = _ws.copyWith(isSaving: true));
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) await Gal.requestAccess(toAlbum: true);

      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      await Gal.putImageBytes(byteData.buffer.asUint8List(),
          name: 'can_wallpaper');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t(lang, 'wallpaper.saved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${I18n.t(lang, 'wallpaper.saveFailed')} $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _ws = _ws.copyWith(isSaving: false));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(themeNotifierProvider).languageCode;
    final cs = Theme.of(context).colorScheme;
    final gradient = _kBgGradients[_ws.bgGradientIndex].gradient;
    final bgImageUrl =
        _ws.useImage ? _kBgImages[_ws.bgImageIndex].url : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t(lang, 'wallpaper.title')),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              _ws.customText != null
                  ? Icons.edit
                  : Icons.edit_outlined,
              color: _ws.customText != null ? cs.primary : null,
            ),
            tooltip: I18n.t(lang, 'wallpaper.customInput'),
            onPressed: _showCustomInputSheet,
          ),
          IconButton(
            icon: const Icon(Icons.shuffle_outlined),
            tooltip: I18n.t(lang, 'wallpaper.otherQuote'),
            onPressed: _loadRandomQuote,
          ),
        ],
      ),
      body: _ws.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: RepaintBoundary(
                          key: _repaintKey,
                          child: _WallpaperCanvas(
                            displayText: _ws.displayText,
                            authorText: _ws.authorText,
                            gradient: gradient,
                            bgImageUrl: bgImageUrl,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _BgTabButton(
                            label: I18n.t(lang, 'wallpaper.gradient'),
                            icon: Icons.gradient,
                            isSelected: _bgTab == 0,
                            onTap: () => setState(() {
                              _bgTab = 0;
                              _ws = _ws.copyWith(useImage: false);
                            }),
                          ),
                          const SizedBox(width: 8),
                          _BgTabButton(
                            label: I18n.t(lang, 'wallpaper.image'),
                            icon: Icons.image_outlined,
                            isSelected: _bgTab == 1,
                            onTap: () => setState(() {
                              _bgTab = 1;
                              _ws = _ws.copyWith(useImage: true);
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_bgTab == 0)
                        _BgGradientPicker(
                          lang: lang,
                          selectedIndex: _ws.bgGradientIndex,
                          onSelect: (i) => setState(() =>
                              _ws = _ws.copyWith(bgGradientIndex: i)),
                        )
                      else
                        _BgImagePicker(
                          lang: lang,
                          selectedIndex: _ws.bgImageIndex,
                          onSelect: (i) => setState(() =>
                              _ws = _ws.copyWith(bgImageIndex: i)),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed:
                              _ws.isSaving ? null : _saveToGallery,
                          icon: _ws.isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Icon(Icons.download_outlined),
                          label: Text(_ws.isSaving
                              ? I18n.t(lang, 'wallpaper.saving')
                              : I18n.t(lang, 'wallpaper.save')),
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
// 배경화면 캔버스
// ---------------------------------------------------------------------------
class _WallpaperCanvas extends StatelessWidget {
  const _WallpaperCanvas({
    required this.displayText,
    required this.authorText,
    required this.gradient,
    this.bgImageUrl,
  });

  final String displayText;
  final String authorText;
  final LinearGradient gradient;
  final String? bgImageUrl;

  @override
  Widget build(BuildContext context) {
    final isLight = bgImageUrl == null &&
        gradient.colors.first.computeLuminance() > 0.4;
    final textColor = isLight ? Colors.black87 : Colors.white;
    final subColor = isLight
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.65);

    Widget bg;
    if (bgImageUrl != null) {
      bg = Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            bgImageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF1A1A2E)),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xBB000000), Color(0x88000000)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      );
    } else {
      bg = Container(decoration: BoxDecoration(gradient: gradient));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(child: bg),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 명언 — FittedBox로 자동 크기 조절
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 260),
                    child: Text(
                      displayText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSerifKr(
                        fontSize: 16,
                        color: textColor,
                        height: 1.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (authorText.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    authorText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSerifKr(
                      fontSize: 12,
                      color: subColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 배경 타입 탭 버튼
// ---------------------------------------------------------------------------
class _BgTabButton extends StatelessWidget {
  const _BgTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? cs.primary
                : cs.outline.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: isSelected
                    ? cs.onPrimary
                    : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: isSelected
                    ? cs.onPrimary
                    : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 그라디언트 선택 위젯
// ---------------------------------------------------------------------------
class _BgGradientPicker extends StatelessWidget {
  const _BgGradientPicker(
      {required this.selectedIndex, required this.onSelect, required this.lang});
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _kBgGradients.length,
        itemBuilder: (_, i) {
          final item = _kBgGradients[i];
          final isSelected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              width: isSelected ? 68 : 52,
              decoration: BoxDecoration(
                gradient: item.gradient,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      isSelected ? cs.primary : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Icon(
                        Icons.check,
                        color:
                            Colors.white.withValues(alpha: 0.9),
                        size: 18,
                      ),
                    )
                  : Center(
                      child: Text(
                        I18n.t(lang, item.label),
                        style: textTheme.labelSmall?.copyWith(
                          color:
                              Colors.white.withValues(alpha: 0.85),
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 배경 이미지 선택 위젯
// ---------------------------------------------------------------------------
class _BgImagePicker extends StatelessWidget {
  const _BgImagePicker(
      {required this.selectedIndex, required this.onSelect, required this.lang});
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _kBgImages.length,
        itemBuilder: (_, i) {
          final img = _kBgImages[i];
          final isSelected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              width: isSelected ? 90 : 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isSelected ? cs.primary : Colors.transparent,
                  width: 3,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      img.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: cs.surfaceContainerHighest),
                    ),
                    if (isSelected)
                      Container(
                        color: cs.primary.withValues(alpha: 0.3),
                        child: const Center(
                          child: Icon(Icons.check_circle,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0x99000000)
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Text(
                          I18n.t(lang, img.label),
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

