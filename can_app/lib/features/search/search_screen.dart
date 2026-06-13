import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/quote_card.dart';
import '../../shared/widgets/state_views.dart';
import 'search_notifier.dart';

// ---------------------------------------------------------------------------
// 카테고리 정의
// ---------------------------------------------------------------------------
class _Category {
  final String label;
  final String tag;       // Firestore 태그 or 키워드
  final bool isKeyword;   // true → searchByKeyword, false → searchByTag
  final List<Color> gradient;
  final IconData icon;

  const _Category({
    required this.label,
    required this.tag,
    this.isKeyword = false,
    required this.gradient,
    required this.icon,
  });
}

const _kCategories = [
  // ── 직업별 ──────────────────────────────────────────────────
  _Category(
    label: '철학자',
    tag: '철학',
    gradient: [Color(0xFF667EEA), Color(0xFF764BA2)],
    icon: Icons.psychology_outlined,
  ),
  _Category(
    label: '기업가',
    tag: '성공',
    gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    icon: Icons.trending_up_rounded,
  ),
  _Category(
    label: '작가',
    tag: '독서',
    gradient: [Color(0xFFFC5C7D), Color(0xFF6A3093)],
    icon: Icons.auto_stories_outlined,
  ),
  _Category(
    label: '과학자',
    tag: '지혜',
    gradient: [Color(0xFF4776E6), Color(0xFF8E54E9)],
    icon: Icons.science_outlined,
  ),
  _Category(
    label: '예술가',
    tag: '예술',
    gradient: [Color(0xFFFF512F), Color(0xFFDD2476)],
    icon: Icons.palette_outlined,
  ),
  _Category(
    label: '운동선수',
    tag: '도전',
    gradient: [Color(0xFF00C9FF), Color(0xFF0077B6)],
    icon: Icons.sports_outlined,
  ),
  _Category(
    label: '정치가',
    tag: '용기',
    gradient: [Color(0xFFF7971E), Color(0xFFFFD200)],
    icon: Icons.account_balance_outlined,
  ),
  _Category(
    label: '종교인',
    tag: '믿음',
    gradient: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
    icon: Icons.self_improvement_outlined,
  ),
  // ── 감정·주제별 ─────────────────────────────────────────────
  _Category(
    label: '사랑',
    tag: '사랑',
    gradient: [Color(0xFFFF6F91), Color(0xFFCC3366)],
    icon: Icons.favorite_border_rounded,
  ),
  _Category(
    label: '행복',
    tag: '행복',
    gradient: [Color(0xFFFFB347), Color(0xFFFF7F50)],
    icon: Icons.wb_sunny_outlined,
  ),
  _Category(
    label: '자기계발',
    tag: '자기계발',
    gradient: [Color(0xFF20BF55), Color(0xFF01BAEF)],
    icon: Icons.rocket_launch_outlined,
  ),
  _Category(
    label: '삶',
    tag: '삶',
    gradient: [Color(0xFFDAA520), Color(0xFFB8860B)],
    icon: Icons.spa_outlined,
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
    if (cat.isKeyword) {
      _controller.text = cat.tag;
      ref.read(searchNotifierProvider.notifier).searchByKeyword(cat.tag);
    } else {
      _controller.text = cat.label;
      ref.read(searchNotifierProvider.notifier).searchByTag(cat.tag);
    }
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
              mainAxisSpacing: 20,   // 아이콘 오버플로우 공간 확보
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
      // clipBehavior.none → 아이콘이 카드 밖으로 살짝 튀어나옴
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.none,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: category.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── 배경 장식: 우측 상단 반투명 원 ──────────────────
              Positioned(
                top: -12,
                right: -12,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              // ── 배경 장식: 좌측 하단 작은 원 ────────────────────
              Positioned(
                bottom: -18,
                left: -10,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              // ── 카테고리명: 좌측 상단 ────────────────────────────
              Positioned(
                top: 14,
                left: 14,
                right: 60,
                child: Text(
                  category.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // ── 아이콘: 우측 하단, 카드 밖으로 살짝 오버플로우 ──
              Positioned(
                bottom: -10,
                right: -4,
                child: Icon(
                  category.icon,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.35),
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
