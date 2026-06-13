import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_shell.dart';
import 'core/theme/theme_notifier.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: CanApp()));
}

class CanApp extends ConsumerWidget {
  const CanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(themeNotifierProvider.notifier).loadSaved();
    });

    final themeState = ref.watch(themeNotifierProvider);
    final themeData = buildThemeData(themeState);

    return MaterialApp(
      title: 'CAN',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      themeAnimationDuration: Duration.zero,
      home: const AppShell(),
    );
  }
}