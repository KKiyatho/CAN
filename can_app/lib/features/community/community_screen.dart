import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
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
    final lang = ref.read(themeNotifierProvider).languageCode;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(lang, 'community.authPending'))),
      );
      return;
    }
    // 게스트(익명) 계정은 읽기·좋아요만 가능하다. 서버 RLS도 동일하게 차단한다.
    if (user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(lang, 'community.registerRequired'))),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PostCreateScreen(),
        fullscreenDialog: true,
      ),
    );
    ref.read(communityNotifierProvider.notifier).refresh();
  }

  Future<bool> _confirm(String lang, String messageKey, String actionKey) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(I18n.t(lang, messageKey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(I18n.t(lang, 'common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(I18n.t(lang, actionKey)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _moderate(CommunityPost post, {required bool mine}) async {
    final lang = ref.read(themeNotifierProvider).languageCode;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      lang,
      mine ? 'community.deleteConfirm' : 'community.reportConfirm',
      mine ? 'community.delete' : 'community.report',
    );
    if (!confirmed) return;
    final notifier = ref.read(communityNotifierProvider.notifier);
    try {
      if (mine) {
        await notifier.deletePost(post.id);
      } else {
        await notifier.reportPost(post.id);
      }
      messenger.showSnackBar(SnackBar(
        content: Text(I18n.t(lang, mine ? 'community.deleted' : 'community.reported')),
      ));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(I18n.t(lang, 'community.actionFailed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(themeNotifierProvider).languageCode;
    final communityState = ref.watch(communityNotifierProvider);
    final myId = ref.watch(currentUserIdProvider);

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
                                isMine: communityState.posts[i].userId == myId,
                                onModerate: () => _moderate(
                                  communityState.posts[i],
                                  mine: communityState.posts[i].userId == myId,
                                ),
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
          height: 132,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: posts.length,
            itemBuilder: (ctx, i) => SizedBox(
              width: 176,
              child: _TopPostCard(
                rank: i + 1,
                post: posts[i],
                lang: lang,
              ),
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
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CommunityAvatar(post: post, radius: 10),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  post.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lang == 'en'
                ? '#$rank'
                : '$rank${I18n.t(lang, 'community.rank')}',
            style: textTheme.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (post.title.isNotEmpty)
            Text(
              post.title,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 4),
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
  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onModerate,
    required this.isMine,
    required this.lang,
  });
  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onModerate;
  final bool isMine;
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
            Row(
              children: [
                _CommunityAvatar(post: post, radius: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PopupMenuButton<void>(
                  tooltip: I18n.t(lang, isMine ? 'community.delete' : 'community.report'),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz, size: 20),
                  itemBuilder: (_) => [
                    PopupMenuItem<void>(
                      onTap: onModerate,
                      child: Text(I18n.t(
                        lang,
                        isMine ? 'community.delete' : 'community.report',
                      )),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (post.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  post.title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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

class _CommunityAvatar extends StatelessWidget {
  final CommunityPost post;
  final double radius;

  const _CommunityAvatar({required this.post, required this.radius});

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeDataUrl(post.avatarImageDataUrl);
    if (bytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(bytes),
      );
    }
    return CircleAvatar(
      radius: radius,
      child: Text(
        post.avatarEmoji.isEmpty ? '🐣' : post.avatarEmoji,
        style: TextStyle(fontSize: radius),
      ),
    );
  }

  Uint8List? _decodeDataUrl(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    final idx = dataUrl.indexOf(',');
    if (idx < 0 || idx == dataUrl.length - 1) return null;
    try {
      return base64Decode(dataUrl.substring(idx + 1));
    } catch (_) {
      return null;
    }
  }
}
