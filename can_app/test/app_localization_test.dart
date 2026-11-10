import 'dart:io';

import 'package:can_app/core/theme/i18n.dart';
import 'package:can_app/core/theme/theme_notifier.dart';
import 'package:can_app/shared/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Korean and English tables cover the same UI keys', () {
    final source = File('lib/core/theme/i18n.dart').readAsStringSync();
    final tables = source.split('static const Map<String, String> _en =');
    Set<String> keys(String source) => RegExp(
      r"^\s*'([^']+)':",
      multiLine: true,
    ).allMatches(source).map((match) => match[1]!).toSet();
    expect(keys(tables[0]), keys(tables[1]));
    for (final key in keys(tables[1])) {
      expect(I18n.t('en', key), isNot(key), reason: key);
      expect(I18n.t('en', key), isNot(matches(RegExp('[가-힣]'))), reason: key);
    }
  });

  testWidgets('Common UI and Flutter menus switch language and persist', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeNotifierProvider.notifier).loadSaved();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final lang = ref.watch(themeNotifierProvider).languageCode;
            return MaterialApp(
              locale: Locale(lang),
              supportedLocales: const [Locale('ko'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: Scaffold(
                body: Column(
                  children: [
                    const EmptyView(),
                    ErrorView(message: 'test', onRetry: () {}),
                    Builder(
                      builder: (context) => Text(
                        MaterialLocalizations.of(context).cancelButtonLabel,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('다시 시도'), findsOneWidget);
    await container.read(themeNotifierProvider.notifier).setLanguage('en');
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('No results found.'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    await restored.read(themeNotifierProvider.notifier).loadSaved();
    expect(restored.read(themeNotifierProvider).languageCode, 'en');
    await container.read(themeNotifierProvider.notifier).setLanguage('ko');
    await tester.pumpAndSettle();
    expect(find.text('다시 시도'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
