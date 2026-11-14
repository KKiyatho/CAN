import 'package:can_app/core/theme/i18n.dart';
import 'package:can_app/features/community/post_create_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('제목과 내용을 입력하면 등록 버튼이 활성화된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PostCreateScreen())),
    );
    final submit = find.widgetWithText(TextButton, I18n.t('ko', 'postCreate.submit'));
    expect(tester.widget<TextButton>(submit).onPressed, isNull);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '오늘의 다짐');
    await tester.pump();
    expect(tester.widget<TextButton>(submit).onPressed, isNull);

    await tester.enterText(fields.at(1), '조금씩 나아가는 중입니다');
    await tester.pump();
    expect(tester.widget<TextButton>(submit).onPressed, isNotNull);

    await tester.enterText(fields.at(1), '');
    await tester.pump();
    expect(tester.widget<TextButton>(submit).onPressed, isNull);
  });
}
