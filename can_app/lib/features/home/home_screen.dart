import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../../core/firebase/auth_providers.dart';
import '../../core/theme/i18n.dart';
import '../../core/theme/theme_notifier.dart';
import '../profile/profile_repository.dart';
import '../profile/user_profile.dart';
import '../../shared/models/quote.dart';
import '../../shared/widgets/quote_card.dart';
import '../../shared/widgets/state_views.dart';
import '../search/search_notifier.dart';
import 'home_notifier.dart';
import 'quote_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeNotifierProvider);
    final themeState = ref.watch(themeNotifierProvider);
    final lang = themeState.languageCode;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CAN',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: I18n.t(lang, 'profile.tooltip'),
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => _openProfileSheet(context, homeState),
          ),
          // 다크모드 토글
          IconButton(
            tooltip: I18n.t(lang, 'home.darkModeTooltip'),
            icon: Icon(
              themeState.isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () =>
                ref.read(themeNotifierProvider.notifier).toggleDarkMode(),
          ),
          // 언어 선택
          IconButton(
            tooltip: I18n.t(lang, 'home.languageTooltip'),
            icon: const Icon(Icons.translate),
            onPressed: () => _showLanguagePicker(context, ref, themeState),
          ),
          // 테마 색상 선택
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _showColorPicker(context, ref, themeState),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: themeState.primaryColor,
                child: Icon(Icons.palette,
                    size: 16, color: colorScheme.onPrimary),
              ),
            ),
          ),
        ],
      ),
      body: homeState.quote.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '${I18n.t(lang, 'home.loadError')}\n$e',
          onRetry: () =>
              ref.read(homeNotifierProvider.notifier).loadQuote(),
        ),
        data: (quote) => _QuoteBody(
          quote: homeState,
          onRefresh: () =>
              ref.read(homeNotifierProvider.notifier).loadQuote(),
          onBookmark: () =>
              ref.read(homeNotifierProvider.notifier).toggleBookmark(quote.id),
          onLike: () =>
              ref.read(homeNotifierProvider.notifier).toggleLike(quote.id),
          onShare: () => Share.share(quote.shareText),
        ),
      ),
    );
  }

  void _openProfileSheet(BuildContext context, HomeState homeState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _ProfileBottomSheet(homeState: homeState),
      ),
    );
  }

  void _showColorPicker(
      BuildContext context, WidgetRef ref, ThemeState themeState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(I18n.t(themeState.languageCode, 'home.themeTitle'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(kThemeColors.length, (i) {
                final isSelected = themeState.colorIndex == i;
                return GestureDetector(
                  onTap: () {
                    ref
                        .read(themeNotifierProvider.notifier)
                        .setColor(i);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kThemeColors[i],
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3)
                          : null,
                      boxShadow: [
                        BoxShadow(
                            color: kThemeColors[i].withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 22)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(
      BuildContext context, WidgetRef ref, ThemeState themeState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(I18n.t(themeState.languageCode, 'home.languageTitle'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 16),
            ...kLanguageOptions.map((opt) {
              final isSelected = themeState.languageCode == opt.code;
              return ListTile(
                title: Text(opt.label),
                trailing: isSelected
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () async {
                  await ref
                      .read(themeNotifierProvider.notifier)
                      .setLanguage(opt.code);
                  // 언어 변경 후 명언 새로 로드 + 검색 결과 초기화
                  ref.read(homeNotifierProvider.notifier).loadQuote();
                  ref.read(searchNotifierProvider.notifier).clearSearch();
                  if (context.mounted) Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ProfileBottomSheet extends ConsumerStatefulWidget {
  final HomeState homeState;

  const _ProfileBottomSheet({required this.homeState});

  @override
  ConsumerState<_ProfileBottomSheet> createState() =>
      _ProfileBottomSheetState();
}

class _ProfileBottomSheetState extends ConsumerState<_ProfileBottomSheet> {
  late Future<_ProfileData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadProfileData();
  }

  Future<_ProfileData> _loadProfileData() async {
    final repo = ref.read(quoteRepositoryProvider);
    final bookmarked = await repo.fetchQuotesByIds(
      widget.homeState.bookmarkedIds,
    );
    final liked = await repo.fetchQuotesByIds(
      widget.homeState.likedIds,
    );
    return _ProfileData(bookmarked: bookmarked, liked: liked);
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final lang = ref.watch(themeNotifierProvider).languageCode;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayName = _displayName(authUser, profile);
    final subtitle = _subtitle(authUser, profile, lang);
    final initial = displayName.isEmpty ? '?' : displayName.substring(0, 1);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.transparent,
                  child: _ProfileAvatar(
                    imageDataUrl: profile?.avatarImageDataUrl,
                    emoji: profile?.avatarEmoji ?? '🐣',
                    fallback: initial,
                    radius: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: authUser == null
                        ? null
                        : () async {
                            await _openEditProfile(context, authUser, profile);
                            if (mounted) {
                              ref.invalidate(currentUserProfileProvider);
                            }
                          },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(I18n.t(lang, 'profile.edit')), 
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: authUser == null
                        ? null
                        : () async {
                            await ref.read(firebaseAuthProvider).signOut();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                    icon: const Icon(Icons.logout),
                    label: Text(I18n.t(lang, 'profile.logout')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: FutureBuilder<_ProfileData>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: I18n.t(lang, 'profile.loadError'),
                      onRetry: () {
                        setState(() {
                          _future = _loadProfileData();
                        });
                      },
                    );
                  }

                  final data = snapshot.data ??
                      const _ProfileData(bookmarked: [], liked: []);
                  return DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _StatChip(
                              icon: Icons.bookmark,
                              label: I18n.t(lang, 'profile.savedCount'),
                              count: data.bookmarked.length,
                            ),
                            const SizedBox(width: 8),
                            _StatChip(
                              icon: Icons.favorite,
                              label: I18n.t(lang, 'profile.likedCount'),
                              count: data.liked.length,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TabBar(
                          tabs: [
                            Tab(text: I18n.t(lang, 'profile.savedTab')),
                            Tab(text: I18n.t(lang, 'profile.likedTab')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _QuoteListView(
                                quotes: data.bookmarked,
                                emptyText: I18n.t(lang, 'profile.savedEmpty'),
                              ),
                              _QuoteListView(
                                quotes: data.liked,
                                emptyText: I18n.t(lang, 'profile.likedEmpty'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditProfile(
    BuildContext context,
    User authUser,
    UserProfile? profile,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _EditProfileSheet(
          user: authUser,
          initialProfile: profile,
        ),
      ),
    );
  }

  String _displayName(User? authUser, UserProfile? profile) {
    final profileName = profile?.displayName.trim() ?? '';
    if (profileName.isNotEmpty) return profileName;
    if (authUser == null) return 'Guest';
    if (authUser.isAnonymous) return 'Guest';
    final name = authUser.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = authUser.email?.trim();
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'User';
  }

  String _subtitle(User? authUser, UserProfile? profile, String lang) {
    if (profile != null && profile.displayName.trim().isNotEmpty) {
      return I18n.t(lang, 'profile.savedProfile');
    }
    if (authUser == null || authUser.isAnonymous) {
      return I18n.t(lang, 'profile.guestSubtitle');
    }
    final email = authUser.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return I18n.t(lang, 'profile.userSubtitle');
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$label $count',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteListView extends StatelessWidget {
  final List<Quote> quotes;
  final String emptyText;

  const _QuoteListView({
    required this.quotes,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (quotes.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: quotes.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final q = quotes[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          title: Text(
            q.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            q.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? imageDataUrl;
  final String emoji;
  final String fallback;
  final double radius;

  const _ProfileAvatar({
    required this.imageDataUrl,
    required this.emoji,
    required this.fallback,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bytes = _decodeDataUrl(imageDataUrl);
    if (bytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(bytes),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      child: Text(
        emoji.trim().isNotEmpty ? emoji : fallback,
        style: Theme.of(context).textTheme.titleLarge,
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

class _EditProfileSheet extends ConsumerStatefulWidget {
  final User user;
  final UserProfile? initialProfile;

  const _EditProfileSheet({
    required this.user,
    required this.initialProfile,
  });

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  static const _animals = [
    '🐶',
    '🐱',
    '🐰',
    '🦊',
    '🐻',
    '🐼',
    '🐨',
    '🐯',
    '🦁',
    '🐮',
    '🐷',
    '🐸',
    '🐵',
    '🐣',
  ];

  late final TextEditingController _nameController;
  late String _selectedEmoji;
  String? _imageDataUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    final authName = widget.user.displayName?.trim() ?? '';
    _nameController = TextEditingController(
      text: profile?.displayName.isNotEmpty == true
          ? profile!.displayName
          : (authName.isNotEmpty ? authName : ''),
    );
    _selectedEmoji = profile?.avatarEmoji ?? '🐣';
    _imageDataUrl = profile?.avatarImageDataUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;

    // ── 파일 시그니처(magic bytes) 검증: 허용 포맷만 수락 ──────────────
    final mime = _detectMimeType(bytes);
    if (mime == null) {
      if (!mounted) return;
      final lang = ref.read(themeNotifierProvider).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(lang, 'profile.invalidImageType'))),
      );
      return;
    }

    if (bytes.length > 150 * 1024) {
      if (!mounted) return;
      final lang = ref.read(themeNotifierProvider).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(lang, 'profile.imageTooLarge'))),
      );
      return;
    }

    setState(() {
      _imageDataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  /// 파일 시그니처(magic bytes)로 MIME 타입 판별.
  /// 허용 포맷(JPEG, PNG, GIF, WebP)이 아니면 null 반환.
  static String? _detectMimeType(List<int> bytes) {
    if (bytes.length < 4) return null;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 &&
        bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'image/png';
    }
    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 && bytes[1] == 0x49 &&
        bytes[2] == 0x46 && bytes[3] == 0x38) {
      return 'image/gif';
    }
    // WebP: 52 49 46 46 ... 57 45 42 50 (RIFF....WEBP)
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 &&
        bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 &&
        bytes[10] == 0x42 && bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  Future<void> _save() async {
    final lang = ref.read(themeNotifierProvider).languageCode;
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty || trimmedName.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(lang, 'profile.nameRule'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.saveProfile(UserProfile(
        uid: widget.user.uid,
        displayName: trimmedName,
        avatarEmoji: _selectedEmoji,
        avatarImageDataUrl: _imageDataUrl,
      ));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(lang, 'profile.saveFailed'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(themeNotifierProvider).languageCode;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              I18n.t(lang, 'profile.editTitle'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            Center(
              child: _ProfileAvatar(
                imageDataUrl: _imageDataUrl,
                emoji: _selectedEmoji,
                fallback: 'U',
                radius: 36,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload),
                  label: Text(I18n.t(lang, 'profile.uploadImage')),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _imageDataUrl = null),
                  icon: const Icon(Icons.image_not_supported_outlined),
                  label: Text(I18n.t(lang, 'profile.useEmojiOnly')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: I18n.t(lang, 'profile.nameLabel'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              I18n.t(lang, 'profile.emojiTitle'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _animals.map((emoji) {
                final selected = emoji == _selectedEmoji;
                return InkWell(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(I18n.t(lang, 'profile.save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileData {
  final List<Quote> bookmarked;
  final List<Quote> liked;

  const _ProfileData({
    required this.bookmarked,
    required this.liked,
  });
}

// ---------------------------------------------------------------------------
// 명언 본문 영역
// ---------------------------------------------------------------------------
class _QuoteBody extends ConsumerWidget {
  final HomeState quote;
  final VoidCallback onRefresh;
  final VoidCallback onBookmark;
  final VoidCallback onLike;
  final VoidCallback onShare;

  const _QuoteBody({
    required this.quote,
    required this.onRefresh,
    required this.onBookmark,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = quote.quote.value!;
    final isBookmarked = quote.isBookmarked(q.id);
    final isLiked = quote.isLiked(q.id);
    final colorScheme = Theme.of(context).colorScheme;
    final lang = ref.watch(themeNotifierProvider).languageCode;
    final homeState = quote;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final profileIncomplete = authUser != null &&
        (profile == null || !profile.isCompleted);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          children: [
            if (profileIncomplete)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_add_alt_1_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        I18n.t(lang, 'profile.setupPrompt'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (_) => FractionallySizedBox(
                            heightFactor: 0.85,
                            child: _ProfileBottomSheet(homeState: homeState),
                          ),
                        );
                      },
                      child: Text(I18n.t(lang, 'profile.setupNow')),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Center(
                child: QuoteCard(
                    quote: q, label: I18n.t(lang, 'home.todayQuote')),
              ),
            ),

            // ── 하단 액션 버튼 (Thumb-Zone) ──────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 좋아요
                  _ActionButton(
                    icon: isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: I18n.t(lang, 'home.like'),
                    color: isLiked ? Colors.redAccent : null,
                    onTap: onLike,
                  ),
                  // 북마크
                  _ActionButton(
                    icon: isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    label: I18n.t(lang, 'home.save'),
                    color: isBookmarked ? colorScheme.primary : null,
                    onTap: onBookmark,
                  ),
                  // 공유
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: I18n.t(lang, 'home.share'),
                    onTap: onShare,
                  ),
                  // 다른 명언
                  _ActionButton(
                    icon: Icons.refresh,
                    label: I18n.t(lang, 'home.nextQuote'),
                    onTap: onRefresh,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 28,
                color: color ?? theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
