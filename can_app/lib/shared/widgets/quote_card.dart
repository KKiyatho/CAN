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
    // 화면 너비에 따라 패딩·폰트 크기 조정
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 400;
    final hPad = isNarrow ? 18.0 : 28.0;
    final vPad = isNarrow ? 24.0 : 36.0;
    final contentStyle = isNarrow
        ? theme.textTheme.titleMedium?.copyWith(
            height: 1.7,
            fontWeight: FontWeight.w500,
          )
        : theme.textTheme.titleLarge?.copyWith(
            height: 1.6,
            fontWeight: FontWeight.w500,
          );

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
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

            // 명언 본문 — justify 제거 (한국어 모바일에서 단어 간격 왜곡)
            Text(
              '"${quote.content}"',
              style: contentStyle,
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
                Flexible(
                  child: Text(
                    quote.author,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (quote.source != null) ...[
                  Flexible(
                    child: Text(
                      ' · ${quote.source}',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
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
