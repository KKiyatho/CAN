import 'package:can_app/features/alarm/alarm_unlock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('정확히 일치해야 콜백을 한 번 호출하고 실시간 진행도를 갱신한다', (tester) async {
    var unlocked = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AlarmUnlockScreen(
            phrase: '나는 할 수 있다',
            isRinging: true,
            onUnlocked: () async {
              unlocked++;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '나는');
    await tester.pump();
    final rich = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere(
          (widget) =>
              widget.text.toPlainText() == '나는 할 수 있다' &&
              widget.text is TextSpan &&
              (widget.text as TextSpan).children != null,
        );
    final spans = (rich.text as TextSpan).children!.cast<TextSpan>();
    expect(spans.first.style!.color, isNot(spans.last.style!.color));
    await tester.enterText(find.byType(TextField), '나는 할 수 있다 ');
    await tester.pump();
    expect(unlocked, 0);
    await tester.enterText(find.byType(TextField), '나는 할 수 있다');
    await tester.pump();
    expect(unlocked, 1);
    await tester.pump();
    expect(unlocked, 1);
  });

  testWidgets('저장 실패 후 다시 시도할 수 있고 작은 화면·키보드에도 overflow 없음', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.reset);
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AlarmUnlockScreen(
            phrase: '정확히',
            isRinging: true,
            onUnlocked: () async {
              attempts++;
              if (attempts == 1) throw StateError('저장 실패');
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '정확히');
    await tester.pump();
    expect(find.textContaining('해제 저장 실패'), findsOneWidget);
    await tester.ensureVisible(find.text('해제 저장 다시 시도'));
    await tester.tap(find.text('해제 저장 다시 시도'));
    await tester.pump();
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });
}
