import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/quote_card.dart';
import '../../shared/widgets/state_views.dart';
import 'search_notifier.dart';
import 'tag_extractor.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _keywordController = TextEditingController();
  final _emotionController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 무한 스크롤 감지
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(searchNotifierProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _emotionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('검색 · 추천',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // ── 검색/감정 입력 영역 ──────────────────────────────────────
          Container(
            color: colorScheme.surfaceContainerLowest,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // 키워드 검색창
                TextField(
                  controller: _keywordController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '인물, 키워드로 검색',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _keywordController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _keywordController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (v) => ref
                      .read(searchNotifierProvider.notifier)
                      .searchByKeyword(v),
                ),
                const SizedBox(height: 10),

                // 감정/상황 입력창
                TextField(
                  controller: _emotionController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: '지금 어떤 마음인가요? (예: 면접이 걱정돼요)',
                    prefixIcon: const Icon(Icons.psychology_outlined),
                    suffixIcon: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () => ref
                          .read(searchNotifierProvider.notifier)
                          .searchByEmotion(_emotionController.text),
                      child: const Text('추천'),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                  onSubmitted: (v) => ref
                      .read(searchNotifierProvider.notifier)
                      .searchByEmotion(v),
                ),

                // 추출된 태그 표시
                if (state.selectedTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: state.selectedTags
                          .map((t) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Chip(
                                  label: Text(t),
                                  backgroundColor:
                                      colorScheme.primaryContainer,
                                  labelStyle: TextStyle(
                                      color:
                                          colorScheme.onPrimaryContainer),
                                  padding: EdgeInsets.zero,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── 감정 태그 칩 바 ─────────────────────────────────────────
          Container(
            height: 44,
            color: colorScheme.surface,
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              children: TagExtractor.allTags.map((tag) {
                final isSelected = state.selectedTags.contains(tag) &&
                    state.emotionInput.isEmpty &&
                    state.keyword.isEmpty;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (_) => ref
                        .read(searchNotifierProvider.notifier)
                        .searchByTag(tag),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          // ── 최근 검색어 ──────────────────────────────────────────────
          if (state.results.value?.isEmpty == true &&
              state.recentSearches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text('최근 검색',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.outline)),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: state.recentSearches.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InputChip(
                      label: Text(s),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => ref
                          .read(searchNotifierProvider.notifier)
                          .removeRecentSearch(s),
                      onPressed: () {
                        _keywordController.text = s;
                        ref
                            .read(searchNotifierProvider.notifier)
                            .searchByKeyword(s);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
          ],

          // ── 결과 목록 ────────────────────────────────────────────────
          Expanded(
            child: state.results.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: '검색 중 오류가 발생했습니다.',
                onRetry: () => ref
                    .read(searchNotifierProvider.notifier)
                    .searchByKeyword(_keywordController.text),
              ),
              data: (quotes) {
                if (quotes.isEmpty &&
                    (state.keyword.isNotEmpty ||
                        state.emotionInput.isNotEmpty ||
                        state.selectedTags.isNotEmpty)) {
                  return const EmptyView(
                      message: '관련 명언을 찾지 못했습니다.\n다른 키워드를 입력해 보세요.');
                }
                if (quotes.isEmpty) {
                  return const EmptyView(
                      message: '검색어나 감정 상황을 입력해 보세요.');
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
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
            ),
          ),
        ],
      ),
    );
  }
}
