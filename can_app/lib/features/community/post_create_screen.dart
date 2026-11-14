import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
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
  const PostCreateScreen({super.key});

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

  // 등록 버튼 활성화(isValid)가 입력 내용에 따라 달라지므로 오류 문구가 같아도 항상 다시 그린다.
  void _onTitleChanged(String value) {
    final lang = ref.read(themeNotifierProvider).languageCode;
    setState(() => _titleValidationError = _validateTitle(value, lang));
  }

  void _onChanged(String value) {
    final lang = ref.read(themeNotifierProvider).languageCode;
    setState(() => _validationError = _validateContent(value, lang));
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
      final authUser = ref.read(authStateProvider).valueOrNull;
      if (authUser == null) {
        throw const CommunityException(CommunityFailure.unknown);
      }
      // 게시글은 저장된 프로필에 연결되므로 먼저 프로필을 보장한다.
      final profileRepo = ref.read(profileRepositoryProvider);
      final profile = await profileRepo.resolveEffectiveProfile(authUser);
      await profileRepo.saveProfile(profile);
      await ref.read(communityRepositoryProvider).createPost(
            title: title,
            content: content,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        final failure = e is CommunityException ? e.failure : null;
        final key = switch (failure) {
          CommunityFailure.registrationRequired => 'community.registerRequired',
          CommunityFailure.rateLimited => 'postCreate.rateLimit',
          _ => 'postCreate.fail',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t(lang, key))),
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
