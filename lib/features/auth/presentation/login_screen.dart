import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_page.dart';
import '../application/session_notifier.dart';
import 'widgets/auth_form_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _authError;
  bool _submittingEmail = false;
  bool _submittingApple = false;
  bool _submittingGoogle = false;

  bool get _busy => _submittingEmail || _submittingApple || _submittingGoogle;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submitEmailPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _authError = null;
      _submittingEmail = true;
    });
    try {
      final message = await ref.read(sessionProvider.notifier).loginWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (!mounted) {
        return;
      }
      if (message != null) {
        setState(() => _authError = message);
      }
    } finally {
      if (mounted) {
        setState(() => _submittingEmail = false);
      }
    }
  }

  Future<void> _submitApple() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _authError = null;
      _submittingApple = true;
    });
    try {
      final message = await ref.read(sessionProvider.notifier).loginWithApple();
      if (!mounted) {
        return;
      }
      if (message != null) {
        setState(() => _authError = message);
      }
    } finally {
      if (mounted) {
        setState(() => _submittingApple = false);
      }
    }
  }

  Future<void> _submitGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _authError = null;
      _submittingGoogle = true;
    });
    try {
      final message = await ref.read(sessionProvider.notifier).loginWithGoogle();
      if (!mounted) {
        return;
      }
      if (message != null) {
        setState(() => _authError = message);
      }
    } finally {
      if (mounted) {
        setState(() => _submittingGoogle = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AuthScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              title: 'Sign in',
              subtitle: 'Welcome back. Sign in to continue tracking your expenses.',
            ),
            if (_authError != null) ...[
              const SizedBox(height: 20),
              AuthErrorBanner(message: _authError!),
            ],
            const SizedBox(height: 28),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: authFieldDecoration(
                      context,
                      label: 'Email',
                      prefixIcon: Icon(
                        Icons.mail_outline_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) {
                        return 'Enter your email';
                      }
                      if (!v.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AuthPasswordField(
                    controller: _password,
                    label: 'Password',
                    autofillHints: const [AutofillHints.password],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submitEmailPassword,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _submittingEmail
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 20),
                  const AuthOrDivider(),
                  const SizedBox(height: 20),
                  AppleSignInButton(
                    onPressed: _busy ? null : _submitApple,
                    loading: _submittingApple,
                  ),
                  const SizedBox(height: 12),
                  GoogleSignInButton(
                    onPressed: _busy ? null : _submitGoogle,
                    loading: _submittingGoogle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AuthFooterLink(
              prompt: "Don't have an account?",
              actionLabel: 'Create one',
              onPressed: _busy
                  ? null
                  : () {
                      ref.read(authPageProvider.notifier).state = AuthPage.register;
                    },
            ),
          ],
        ),
      ),
    );
  }
}
