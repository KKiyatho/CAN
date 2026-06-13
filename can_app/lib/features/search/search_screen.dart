import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/quote_card.dart';
import '../../shared/widgets/state_views.dart';
import 'category_detail_screen.dart';
import 'search_notifier.dart';

// ---------------------------------------------------------------------------
// 카테고리 정의
// ---------------------------------------------------------------------------
class _Category {
  final String label;
  final String tag;       // Firestore 태그 or 키워드
  final bool isKeyword;   // true → searchByKeyword, false → searchByTag
  final List<Color> gradient;
  final String imageUrl;  // Unsplash 이미지 URL

  const _Category({
    required this.label,
    required this.tag,
    this.isKeyword = false,
    required this.gradient,
    required this.imageUrl,
  });
}

const _kCategories = [
  // ── 직업별 ──────────────────────────────────────────────────
  _Category(
    label: '철학자',
    tag: '철학',
    gradient: [Color(0xFF667EEA), Color(0xFF764BA2)],
    imageUrl: 'https://images.unsplash.com/photo-1541701494587-cb58502866ab?w=400&q=80&fit=crop',
  ),
  _Category(
    label: '기업가',
    tag: '성공',
    gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    imageUrl: 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=400&q=80&fit=crop',
  ),
  _Category(
    label: '작가',
    tag: '독서',
    gradient: [Color(0xFFFC5C7D), Color(0xFF6A3093)],
    imageUrl: 'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=400&q=80&fit=crop',
  ),
  _Category(
    label: '과학자',
    tag: '지혜',
    gradient: [Color(0xFF4776E6), Color(0xFF8E54E9)],
    imageUrl: 'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=400&q=80&fit=crop',
  ),
  _Category(
    label: '예술가',
    tag: '창의력',
    gradient: [Color(0xFFFF512F), Color(0xFFDD2476)],
    imageUrl: 'https://images.unsplash.com/photo-1547036967-23d11aacaee0?w=400&q=80&fit=crop',
  ),
  _Category(
    label: '운동선수',
    tag: '도전',
    gradient: [Color(0xFF00C9FF), Color(0xFF0077B6)],
    imageUrl: 'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=400&q=80&fit=crop',
  ),
  _Category(
    label: '정치가',
    tag: '용기',
    gradient: [Color(0xFFF7971E), Color(0xFFFFD200)],
    imageUrl: 'https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?w=400&q=80&fit=crop',
  ),
  _Category(
    label: '종교인',
    tag: '믿음',
    gradient: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
    imageUrl: 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=400&q=80&fit=crop',
  ),
  // ── 감정·주제별 ─────────────────────────────────────────────
  _Category(
    label: '사랑',
    tag: '사랑',
    gradient: [Color(0xFFFF6F91), Color(0xFFCC3366)],
    imageUrl: 'https://images.unsplash.com/photo-1518895949257-7621c3c786d7?w=400&q=80&fit=crop',
  ),
  _Category(
    label: '행복',
    tag: '행복',
    gradient: [Color(0xFFFFB347), Color(0xFFFF7F50)],
    imageUrl: 'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?w=400&q=80&fit=crop',
  ),
  _Category(
    label: '자기계발',
    tag: '자기계발',
    gradient: [Color(0xFF20BF55), Color(0xFF01BAEF)],
    imageUrl: 'https://images.unsplash.com/photo-1434754205268-ad3b5f549b11?w=400&q=80&fit=crop',
  ),
  _Category(
    label: '삶',
    tag: '삶',
    gradient: [Color(0xFFDAA520), Color(0xFFB8860B)],
    imageUrl: 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=400&q=80&fit=crop',
  ),
];

// ---------------------------------------------------------------------------
// SearchScreen
// ---------------------------------------------------------------------------
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(searchNotifierProvider.notifier).loadMore();
      }
    });
    _focusNode.addListener(() {
      setState(() => _isSearching = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _isSearching = false);
    ref.read(searchNotifierProvider.notifier).clearSearch();
  }

  void _submit(String v) {
    if (v.trim().isEmpty) return;
    _focusNode.unfocus();
    setState(() => _isSearching = false);
    ref.read(searchNotifierProvider.notifier).searchByKeyword(v);
  }

  void _selectCategory(_Category cat) {
    _focusNode.unfocus();
    setState(() => _isSearching = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryDetailScreen(
          label: cat.label,
          tag: cat.tag,
          gradient: cat.gradient,
          imageUrl: cat.imageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showResults = state.keyword.isNotEmpty ||
        state.selectedTags.isNotEmpty ||
        _isSearching;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 타이틀 ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 150),
                crossFadeState: _isSearching
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Text(
                  '검색',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ),

            // ── 검색바 ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _submit,
                      decoration: InputDecoration(
                        hintText: '명언, 인물, 상황 검색',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel, size: 18),
                                onPressed: _clear,
                              )
                            : null,
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_isSearching) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _clear,
                      child: const Text('취소'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 본문: 카테고리 그리드 or 검색 결과 ──────────────────
            Expanded(
              child: showResults
                  ? _ResultsView(
                      state: state,
                      scrollController: _scrollController,
                      onRetry: () =>
                          ref.read(searchNotifierProvider.notifier)
                              .searchByKeyword(_controller.text),
                      recentSearches: state.recentSearches,
                      onRecentTap: (s) {
                        _controller.text = s;
                        _submit(s);
                      },
                      onRecentDelete: (s) => ref
                          .read(searchNotifierProvider.notifier)
                          .removeRecentSearch(s),
                    )
                  : _CategoryGrid(onTap: _selectCategory),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 카테고리 그리드
// ---------------------------------------------------------------------------
class _CategoryGrid extends StatelessWidget {
  final void Function(_Category) onTap;

  const _CategoryGrid({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Text(
              '카테고리 둘러보기',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _CategoryCard(
                category: _kCategories[i],
                onTap: () => onTap(_kCategories[i]),
              ),
              childCount: _kCategories.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final _Category category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        // overflow: hidden — 이미지가 카드 밖으로 절대 탈출하지 않음
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: category.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // ── 1. 실제 이미지 (우측 배치, 투명도 0.72) ─────────
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 130,
                child: Opacity(
                  opacity: 0.72,
                  child: Image.network(
                    category.imageUrl,
                    fit: BoxFit.cover,
                    // 이미지 로드 실패 시 조용히 빈칸 처리
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : const SizedBox.shrink(),
                  ),
                ),
              ),
              // ── 2. 좌→우 그라디언트 블렌드 마스크 ───────────────
              // 이미지와 배경색이 자연스럽게 섞이는 Apple Music 효과
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        category.gradient.first,
                        category.gradient.first.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.38, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
              // ── 3. 카테고리명: 좌측 상단, 흰색 볼드 ─────────────
              Positioned(
                top: 14,
                left: 14,
                right: 72,
                child: Text(
                  category.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.4,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 검색 결과 뷰
// ---------------------------------------------------------------------------
class _ResultsView extends StatelessWidget {
  final SearchState state;
  final ScrollController scrollController;
  final VoidCallback onRetry;
  final List<String> recentSearches;
  final void Function(String) onRecentTap;
  final void Function(String) onRecentDelete;

  const _ResultsView({
    required this.state,
    required this.scrollController,
    required this.onRetry,
    required this.recentSearches,
    required this.onRecentTap,
    required this.onRecentDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return state.results.when(
      loading: () => const LoadingView(),
      error: (e, _) =>
          ErrorView(message: '검색 중 오류가 발생했습니다.', onRetry: onRetry),
      data: (quotes) {
        // 아직 검색 전 → 최근 검색어
        if (quotes.isEmpty &&
            state.keyword.isEmpty &&
            state.selectedTags.isEmpty) {
          if (recentSearches.isEmpty) {
            return const EmptyView(message: '검색어나 카테고리를 선택해 보세요.');
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Text('최근 검색',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: colorScheme.outline)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: recentSearches
                    .map((s) => InputChip(
                          label: Text(s),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => onRecentDelete(s),
                          onPressed: () => onRecentTap(s),
                        ))
                    .toList(),
              ),
            ],
          );
        }

        if (quotes.isEmpty) {
          return const EmptyView(message: '관련 명언을 찾지 못했습니다.\n다른 키워드를 입력해 보세요.');
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: quotes.length + (state.hasMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == quotes.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: QuoteCard(quote: quotes[i]),
            );
          },
        );
      },
    );
  }
}
