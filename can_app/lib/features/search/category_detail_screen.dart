import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../shared/models/quote.dart';
import 'category_detail_notifier.dart';

// ---------------------------------------------------------------------------
// CategoryDetailScreen — Apple Music 스타일 카테고리 상세 화면
// ---------------------------------------------------------------------------
class CategoryDetailScreen extends ConsumerStatefulWidget {
  final String label;       // 카테고리명 (예: "철학자")
  final String tag;         // Firestore 태그 (예: "철학")
  final List<Color> gradient;
  final String imageUrl;    // Unsplash 이미지 URL (헤더 배경)

  const CategoryDetailScreen({
    super.key,
    required this.label,
    required this.tag,
    required this.gradient,
    required this.imageUrl,
  });

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 350) {
      ref.read(categoryDetailProvider(widget.tag).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoryDetailProvider(widget.tag));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Apple Music 스타일 헤더 ─────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            backgroundColor: widget.gradient.first,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.black.withValues(alpha: 0.25),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 18),
              title: Text(
                '${widget.label} 명언집',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.4,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. 배경 이미지
                  Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: widget.gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                  ),
                  // 2. 우측 색 틴트 (Apple Music: 배경색이 우측에서 녹아듦)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          widget.gradient.last.withValues(alpha: 0.55),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                  // 3. 하단 어두운 그라디언트 (타이틀 가독성)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 명언 개수 배지 ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: widget.gradient),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (state.quotes.isNotEmpty)
                    Text(
                      '${state.quotes.length}개 명언',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.outline),
                    ),
                ],
              ),
            ),
          ),

          // ── 초기 로딩 스피너 ────────────────────────────────────────
          if (state.isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )

          // ── 에러 (데이터 없을 때만 표시) ────────────────────────────
          else if (state.error != null && state.quotes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 48, color: colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        state.error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.outline),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => ref
                            .read(categoryDetailProvider(widget.tag).notifier)
                            .retry(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            )

          // ── 빈 결과 ─────────────────────────────────────────────────
          else if (state.quotes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  '아직 명언이 없어요.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.outline),
                ),
              ),
            )

          // ── 명언 리스트 ─────────────────────────────────────────────
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _QuoteListTile(
                    quote: state.quotes[i],
                    gradient: widget.gradient,
                  ),
                  childCount: state.quotes.length,
                ),
              ),
            ),

            // ── 더 불러오기 인디케이터 / 완료 메시지 ──────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: state.isLoadingMore
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : state.hasMore
                        ? const SizedBox.shrink()
                        : Center(
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    color: colorScheme.outline, size: 20),
                                const SizedBox(height: 6),
                                Text(
                                  '모든 명언을 다 봤어요',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _QuoteListTile — 개별 명언 카드
// ---------------------------------------------------------------------------
class _QuoteListTile extends StatelessWidget {
  final Quote quote;
  final List<Color> gradient;

  const _QuoteListTile({required this.quote, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onLongPress: () => Share.share(quote.shareText),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 큰따옴표 장식
                Text(
                  '\u201C',
                  style: TextStyle(
                    color: gradient.first.withValues(alpha: 0.45),
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    height: 0.7,
                  ),
                ),
                const SizedBox(height: 10),
                // 명언 본문
                Text(
                  quote.content,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.65,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 14),
                // 저자 라인 (색 수직 바 + 이름)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradient,
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        quote.source != null
                            ? '${quote.author}  ·  ${quote.source}'
                            : quote.author,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 길게 눌러서 공유 힌트
                    Icon(
                      Icons.ios_share_rounded,
                      size: 15,
                      color: colorScheme.outlineVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
