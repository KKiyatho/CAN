import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/auth_providers.dart';
import '../../core/theme/i18n.dart';
import '../../core/theme/theme_notifier.dart';
import '../profile/profile_repository.dart';
import 'community_repository.dart';

// ---------------------------------------------------------------------------
// 콘텐츠 검증 헬퍼
// ---------------------------------------------------------------------------

/// 게시글 내용 유효성 검사. 문제 없으면 null, 문제 있으면 오류 메시지 반환.
String? _validateContent(String raw, String lang) {
  final trimmed = raw.trim();

  if (trimmed.isEmpty) return I18n.t(lang, 'postCreate.empty');
  if (trimmed.length < 2) return I18n.t(lang, 'postCreate.min');
  if (trimmed.length > 300) return I18n.t(lang, 'postCreate.max');

  // 동일 문자 반복 스팸 방지 (예: "aaaaaaa..." 20자 이상 연속)
  if (RegExp(r'(.)\1{19,}').hasMatch(trimmed)) {
    return I18n.t(lang, 'postCreate.meaningful');
  }

  // 동일 단어/공백 반복 스팸 방지
  if (RegExp(r'(\S+\s*)\1{9,}').hasMatch(trimmed)) {
    return I18n.t(lang, 'postCreate.repeated');
  }

  return null;
}

String? _validateTitle(String raw, String lang) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return I18n.t(lang, 'postCreate.titleEmpty');
  if (trimmed.length > 60) return I18n.t(lang, 'postCreate.titleMax');
  return null;
}

// ---------------------------------------------------------------------------
// PostCreateScreen — 글 작성 화면
// ---------------------------------------------------------------------------
class PostCreateScreen extends ConsumerStatefulWidget {
  const PostCreateScreen({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends ConsumerState<PostCreateScreen> {
  final _titleController = TextEditingController();
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _validationError;
  String? _titleValidationError;

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTitleChanged(String value) {
    final lang = ref.read(themeNotifierProvider).languageCode;
    final error = _validateTitle(value, lang);
    if (_titleValidationError != error) {
      setState(() => _titleValidationError = error);
    }
  }

  void _onChanged(String value) {
    final lang = ref.read(themeNotifierProvider).languageCode;
    final error = _validateContent(value, lang);
    if (_validationError != error) {
      setState(() => _validationError = error);
    }
  }

  Future<void> _submit() async {
    final lang = ref.read(themeNotifierProvider).languageCode;
    final title = _titleController.text.trim();
    final content = _controller.text.trim();
    final titleError = _validateTitle(title, lang);
    final error = _validateContent(content, lang);
    if (titleError != null) {
      setState(() => _titleValidationError = titleError);
      return;
    }
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationError = null;
      _titleValidationError = null;
    });

    try {
      final authUser = ref.read(firebaseAuthProvider).currentUser;
      final currentUid = authUser?.uid;
      final effectiveUid = currentUid ?? widget.userId;
      final profileRepo = ref.read(profileRepositoryProvider);
      final effectiveProfile = authUser == null
          ? null
          : await profileRepo.resolveEffectiveProfile(authUser);
      await ref.read(communityRepositoryProvider).createPost(
        userId: effectiveUid,
        displayName: effectiveProfile?.displayName ?? 'Guest',
        avatarEmoji: effectiveProfile?.avatarEmoji ?? '🐣',
        avatarImageDataUrl: effectiveProfile?.avatarImageDataUrl,
        title: title,
            content: content,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t(lang, 'postCreate.fail'))),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(themeNotifierProvider).languageCode;
    final cs = Theme.of(context).colorScheme;
    final isValid =
      _titleValidationError == null &&
      _validationError == null &&
      _titleController.text.trim().isNotEmpty &&
      _controller.text.trim().length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t(lang, 'postCreate.title')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          _isSubmitting
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator.adaptive(),
                )
              : TextButton(
                  onPressed: isValid ? _submit : null,
                  child: Text(I18n.t(lang, 'postCreate.submit')),
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: I18n.t(lang, 'postCreate.titleHint'),
                errorText: _titleValidationError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outline),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: _onTitleChanged,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                maxLength: 300,
                autofocus: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: I18n.t(lang, 'postCreate.hint'),
                  errorText: _validationError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outline),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: _onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
