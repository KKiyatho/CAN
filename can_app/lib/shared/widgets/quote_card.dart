import 'package:flutter/material.dart';
import '../../shared/models/quote.dart';

/// 앱 전반에서 재사용하는 명언 카드 위젯
class QuoteCard extends StatelessWidget {
  final Quote quote;

  /// 카드 상단 라벨 (예: "오늘의 명언", null이면 표시 안 함)
  final String? label;

  const QuoteCard({super.key, required this.quote, this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 라벨 (선택적)
            if (label != null) ...[
              Text(
                label!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 명언 본문
            Text(
              '"${quote.content}"',
              textAlign: TextAlign.justify,
              style: theme.textTheme.titleLarge?.copyWith(
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            // 저자
            Row(
              children: [
                Container(
                  width: 24,
                  height: 2,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  quote.author,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (quote.source != null) ...[
                  Text(
                    ' · ${quote.source}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
