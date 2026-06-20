import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/auth_providers.dart';
import '../../core/theme/i18n.dart';
import '../../core/theme/theme_notifier.dart';
import '../../shared/widgets/state_views.dart';
import 'community_notifier.dart';
import 'community_post.dart';
import 'post_create_screen.dart';

// ---------------------------------------------------------------------------
// CommunityScreen
// ---------------------------------------------------------------------------
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Anonymous 로그인 — 실패해도 UI는 계속 표시, 글 작성만 막힘
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final auth = ref.read(firebaseAuthProvider);
        await signInAnonymouslyIfNeeded(auth);
      } catch (_) {
        // 인증 실패는 조용히 처리 (피드 읽기는 계속 가능)
        // 로그는 프로덕션에서 외부 모니터링 도구로 전달할 것
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(communityNotifierProvider.notifier).loadMore();
    }
  }

  Future<void> _openCreatePost() async {
    // userId가 없으면 익명 로그인 재시도
    String? userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      try {
        final auth = ref.read(firebaseAuthProvider);
        final user = await signInAnonymouslyIfNeeded(auth);
        userId = user?.uid;
      } catch (_) {}
    }

    if (userId == null) {
      final lang = ref.read(themeNotifierProvider).languageCode;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(lang, 'community.authPending'))),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostCreateScreen(userId: userId!),
        fullscreenDialog: true,
      ),
    );
    ref.read(communityNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(themeNotifierProvider).languageCode;
    final communityState = ref.watch(communityNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t(lang, 'community.title')),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(communityNotifierProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'community_fab',
        onPressed: _openCreatePost,
        child: const Icon(Icons.edit_outlined),
      ),
      body: communityState.isLoading
          ? const LoadingView()
          : communityState.error != null && communityState.posts.isEmpty
              ? ErrorView(
                  message: communityState.error!,
                  onRetry: () =>
                      ref.read(communityNotifierProvider.notifier).refresh(),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(communityNotifierProvider.notifier).refresh(),
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // ── 인기 글 차트 ────────────────────────────────────
                      if (communityState.topPosts.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _TopPostsSection(
                              posts: communityState.topPosts, lang: lang),
                        ),
                      // ── 피드 ────────────────────────────────────────────
                      if (communityState.posts.isEmpty)
                        SliverFillRemaining(
                          child: EmptyView(
                            message: I18n.t(lang, 'community.empty'),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              if (i == communityState.posts.length) {
                                return communityState.isLoadingMore
                                    ? const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                            child:
                                                CircularProgressIndicator()),
                                      )
                                    : const SizedBox.shrink();
                              }
                              return _PostCard(
                                post: communityState.posts[i],
                                lang: lang,
                                onLike: () => ref
                                    .read(communityNotifierProvider.notifier)
                                    .toggleLike(communityState.posts[i].id),
                              );
                            },
                            childCount: communityState.posts.length + 1,
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// 인기 글 가로 스크롤 섹션
// ---------------------------------------------------------------------------
class _TopPostsSection extends StatelessWidget {
  const _TopPostsSection({required this.posts, required this.lang});
  final List<CommunityPost> posts;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.local_fire_department,
                  color: cs.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                I18n.t(lang, 'community.topPosts'),
                style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: posts.length,
            itemBuilder: (ctx, i) => _TopPostCard(
              rank: i + 1,
              post: posts[i],
              lang: lang,
            ),
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }
}

class _TopPostCard extends StatelessWidget {
  const _TopPostCard(
      {required this.rank, required this.post, required this.lang});
  final int rank;
  final CommunityPost post;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang == 'en'
                ? '#$rank'
                : '$rank${I18n.t(lang, 'community.rank')}',
            style: textTheme.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              post.content,
              style: textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              Icon(Icons.favorite, size: 12, color: cs.error),
              const SizedBox(width: 4),
              Text(
                '${post.likeCount}',
                style: textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 피드 카드
// ---------------------------------------------------------------------------
class _PostCard extends StatelessWidget {
  const _PostCard(
      {required this.post, required this.onLike, required this.lang});
  final CommunityPost post;
  final VoidCallback onLike;
  final String lang;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return I18n.t(lang, 'community.justNow');
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}${I18n.t(lang, 'community.minAgo')}';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}${I18n.t(lang, 'community.hourAgo')}';
    }
    return '${diff.inDays}${I18n.t(lang, 'community.dayAgo')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post.content, style: textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  _timeAgo(post.createdAt),
                  style: textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onLike,
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          post.likedByMe
                              ? Icons.favorite
                              : Icons.favorite_border,
                          key: ValueKey(post.likedByMe),
                          size: 20,
                          color: post.likedByMe ? cs.error : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likeCount}',
                        style: textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
