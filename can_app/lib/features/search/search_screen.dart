import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_shell.dart';
import '../../core/theme/i18n.dart';
import '../../core/theme/theme_notifier.dart';
import '../../shared/widgets/quote_card.dart';
import '../../shared/widgets/state_views.dart';
import 'category_detail_screen.dart';
import 'search_notifier.dart';

// ---------------------------------------------------------------------------
// 카테고리 정의
// ---------------------------------------------------------------------------
class _Category {
  final String label;
  final String tag;
  final List<Color> gradient;
  final String imageUrl;

  const _Category({
    required this.label,
    required this.tag,
    required this.gradient,
    required this.imageUrl,
  });
}

String _localizedSearchLabel(String lang, String ko) {
  if (lang != 'en') return ko;
  const map = {
    '철학자': 'Philosophers',
    '기업가': 'Entrepreneurs',
    '작가': 'Writers',
    '과학자': 'Scientists',
    '예술가': 'Artists',
    '운동선수': 'Athletes',
    '정치가': 'Politicians',
    '종교인': 'Religious',
    '사랑': 'Love',
    '행복': 'Happiness',
    '자기계발': 'Self Growth',
    '삶': 'Life',
    '불안': 'Anxiety',
    '지침': 'Exhaustion',
    '면접': 'Interview',
  };
  return map[ko] ?? ko;
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

  // 검색 초기화 (취소 버튼 및 탭 이탈 시 공통 사용)
  void _reset() {
    _controller.clear();
    _focusNode.unfocus();
    if (mounted) setState(() => _isSearching = false);
    ref.read(searchNotifierProvider.notifier).clearSearch();
  }

  void _clear() => _reset();

  void _submit(String v) {
    if (v.trim().isEmpty) return;
    _focusNode.unfocus();
    setState(() => _isSearching = false);
    ref.read(searchNotifierProvider.notifier).searchUnified(v);
  }

  void _selectCategory(_Category cat) {
    _focusNode.unfocus();
    setState(() => _isSearching = false);
    final lang = ref.read(themeNotifierProvider).languageCode;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryDetailScreen(
          label: _localizedSearchLabel(lang, cat.label),
          tag: cat.tag,
          gradient: cat.gradient,
          imageUrl: cat.imageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 검색 탭(인덱스 1)을 벗어나는 순간 상태 초기화 → 돌아오면 첫 화면
    ref.listen(tabIndexProvider, (prev, next) {
      if (prev == 1 && next != 1) _reset();
    });

    final lang = ref.watch(themeNotifierProvider).languageCode;
    final state = ref.watch(searchNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showResults = state.keyword.isNotEmpty ||
        state.selectedTags.isNotEmpty ||
        state.emotionInput.isNotEmpty ||
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
                  I18n.t(lang, 'search.title'),
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
                        hintText: I18n.t(lang, 'search.hint'),
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
                      child: Text(I18n.t(lang, 'search.cancel')),
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
                      lang: lang,
                      state: state,
                      scrollController: _scrollController,
                        onRetry: () => ref
                          .read(searchNotifierProvider.notifier)
                          .retryCurrentSearch(),
                      onClear: _clear,
                      recentSearches: state.recentSearches,
                      onRecentTap: (s) {
                        _controller.text = s;
                        _submit(s);
                      },
                      onRecentDelete: (s) => ref
                          .read(searchNotifierProvider.notifier)
                          .removeRecentSearch(s),
                    )
                  : _CategoryGrid(
                      lang: lang,
                      onTap: _selectCategory,
                      onTagTap: (tag) => ref
                          .read(searchNotifierProvider.notifier)
                          .searchByTag(tag),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 카테고리 그리드 (감정 입력 섹션 포함)
// ---------------------------------------------------------------------------
class _CategoryGrid extends StatelessWidget {
  final String lang;
  final void Function(_Category) onTap;
  final void Function(String) onTagTap;

  const _CategoryGrid({
    required this.lang,
    required this.onTap,
    required this.onTagTap,
  });

  // 빠른 선택용 감정 칩 (TagExtractor 키 중 대표 6개)
  static const _quickEmotions = [
    ('😰', '불안'),
    ('😩', '지침'),
    ('💼', '면접'),
    ('❤️', '사랑'),
    ('😊', '행복'),
    ('📚', '자기계발'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        // ── 감정 빠른 선택 섹션 (입력창은 상단 단일 검색창으로 통합) ─────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  I18n.t(lang, 'search.emotionTitle'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                // 빠른 감정 칩
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _quickEmotions
                      .map((e) => ActionChip(
                            avatar: Text(e.$1,
                                style: const TextStyle(fontSize: 14)),
                            label: Text(_localizedSearchLabel(lang, e.$2)),
                            onPressed: () => onTagTap(e.$2),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                Text(
                  I18n.t(lang, 'search.categoryBrowse'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── 카테고리 그리드 ──────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _CategoryCard(
                category: _kCategories[i],
                lang: lang,
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
  final String lang;
  final VoidCallback onTap;

  const _CategoryCard(
      {required this.category, required this.lang, required this.onTap});

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
                  _localizedSearchLabel(lang, category.label),
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
  final String lang;
  final SearchState state;
  final ScrollController scrollController;
  final VoidCallback onRetry;
  final VoidCallback onClear; // 처음으로 돌아가기
  final List<String> recentSearches;
  final void Function(String) onRecentTap;
  final void Function(String) onRecentDelete;

  const _ResultsView({
    required this.lang,
    required this.state,
    required this.scrollController,
    required this.onRetry,
    required this.onClear,
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
          ErrorView(message: I18n.t(lang, 'search.error'), onRetry: onRetry),
      data: (quotes) {
        // 검색 전 상태 (아직 키워드/태그 없음)
        final isIdle = quotes.isEmpty &&
            state.keyword.isEmpty &&
            state.selectedTags.isEmpty &&
            state.emotionInput.isEmpty;

        // 상단 "처음으로" 버튼 (검색 결과 표시 중에 항상 노출)
        final backBar = Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.arrow_back_ios, size: 14),
            label: Text(I18n.t(lang, 'search.backToHome')),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        );

        if (isIdle) {
          if (recentSearches.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                backBar,
                Expanded(child: EmptyView(message: I18n.t(lang, 'search.emptySelect'))),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              backBar,
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(I18n.t(lang, 'search.recent'),
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: colorScheme.outline)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
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
                ),
              ),
            ],
          );
        }

        if (quotes.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              backBar,
              Expanded(
                child: EmptyView(message: I18n.t(lang, 'search.emptyNoResult')),
              ),
            ],
          );
        }

        // 감정 입력 결과 헤더
        final hasEmotionHeader = state.emotionInput.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            backBar,
            if (hasEmotionHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '"${state.emotionInput}"${I18n.t(lang, 'search.emotionResult')}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
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
              ),
            ),
          ],
        );
      },
    );
  }
}
