import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'community_repository.dart';

// ---------------------------------------------------------------------------
// 콘텐츠 검증 헬퍼
// ---------------------------------------------------------------------------

/// 게시글 내용 유효성 검사. 문제 없으면 null, 문제 있으면 오류 메시지 반환.
String? _validateContent(String raw) {
  final trimmed = raw.trim();

  if (trimmed.isEmpty) return '내용을 입력해 주세요.';
  if (trimmed.length < 2) return '최소 2자 이상 입력해 주세요.';
  if (trimmed.length > 300) return '300자를 초과할 수 없습니다.';

  // 동일 문자 반복 스팸 방지 (예: "aaaaaaa..." 20자 이상 연속)
  if (RegExp(r'(.)\1{19,}').hasMatch(trimmed)) {
    return '의미 있는 내용을 입력해 주세요.';
  }

  // 동일 단어/공백 반복 스팸 방지
  if (RegExp(r'(\S+\s*)\1{9,}').hasMatch(trimmed)) {
    return '반복된 내용은 등록할 수 없습니다.';
  }

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
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _validationError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final error = _validateContent(value);
    if (_validationError != error) {
      setState(() => _validationError = error);
    }
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    final error = _validateContent(content);
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationError = null;
    });

    try {
      await ref.read(communityRepositoryProvider).createPost(
            userId: widget.userId,
            content: content,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('글 작성에 실패했습니다. 잠시 후 다시 시도해 주세요.')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isValid =
        _validationError == null && _controller.text.trim().length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('글 작성'),
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
                  child: const Text('등록'),
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                maxLength: 300,
                autofocus: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: '동기부여가 될 이야기를 나눠보세요...',
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
