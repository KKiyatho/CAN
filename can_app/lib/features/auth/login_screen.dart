import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/theme/i18n.dart';
import '../../core/theme/theme_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInAnonymously() async {
    setState(() => _isSubmitting = true);
    try {
      await signInAnonymouslyIfNeeded();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showError(I18n.t(ref.read(themeNotifierProvider).languageCode, 'login.genericError'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      _showError('이메일과 비밀번호(6자 이상)를 확인해 주세요.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final client = ref.read(supabaseClientProvider);
      if (_isRegisterMode) {
        await client.auth.signUp(email: email, password: password);
      } else {
        await client.auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } on TimeoutException {
      _showError(I18n.t(ref.read(themeNotifierProvider).languageCode, 'login.timeout'));
    } catch (_) {
      _showError(I18n.t(ref.read(themeNotifierProvider).languageCode, 'login.genericError'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final client = ref.read(supabaseClientProvider);
      // 웹: 쿼리/해시를 뺀 origin 만 사용 (Supabase Redirect URLs 허용 목록과 일치시키기 위함)
      final redirect = kIsWeb ? Uri.base.origin : 'can://login-callback';
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirect,
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } on TimeoutException {
      _showError(I18n.t(ref.read(themeNotifierProvider).languageCode, 'login.timeout'));
    } catch (_) {
      _showError(I18n.t(ref.read(themeNotifierProvider).languageCode, 'login.genericError'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(themeNotifierProvider).languageCode;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const Spacer(),
              Text(
                'CAN',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                I18n.t(lang, 'login.subtitle'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  label: Text(I18n.t(lang, 'login.google')),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: I18n.t(lang, 'login.email'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: I18n.t(lang, 'login.password'),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitEmailAuth,
                  child: Text(
                    _isRegisterMode
                        ? I18n.t(lang, 'login.register')
                        : I18n.t(lang, 'login.signIn'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() => _isRegisterMode = !_isRegisterMode),
                child: Text(
                  _isRegisterMode
                      ? I18n.t(lang, 'login.haveAccount')
                      : I18n.t(lang, 'login.noAccount'),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _signInAnonymously,
                icon: const Icon(Icons.person_outline),
                label: Text(I18n.t(lang, 'login.continueGuest')),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
