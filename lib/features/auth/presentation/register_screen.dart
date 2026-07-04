import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_page.dart';
import '../application/session_notifier.dart';
import '../domain/password_rules.dart';
import 'widgets/auth_form_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();
  String? _registerError;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _registerError = null;
      _submitting = true;
    });
    try {
      final message = await ref.read(sessionProvider.notifier).register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            passwordConfirmation: _passwordConfirmation.text,
          );
      if (!mounted) {
        return;
      }
      if (message != null) {
        setState(() => _registerError = message);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AuthScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              title: 'Create account',
              subtitle: 'Set up your account to start tracking expenses.',
            ),
            if (_registerError != null) ...[
              const SizedBox(height: 20),
              AuthErrorBanner(message: _registerError!),
            ],
            const SizedBox(height: 28),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: authFieldDecoration(
                      context,
                      label: 'Name',
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
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
                    autofillHints: const [AutofillHints.newPassword],
                    helperText: passwordMinLengthHint(),
                    validator: validatePasswordMinLength,
                  ),
                  const SizedBox(height: 12),
                  AuthPasswordField(
                    controller: _passwordConfirmation,
                    label: 'Confirm password',
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm your password';
                      }
                      if (value != _password.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create account'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AuthFooterLink(
              prompt: 'Already have an account?',
              actionLabel: 'Sign in',
              onPressed: busy
                  ? null
                  : () {
                      ref.read(authPageProvider.notifier).state = AuthPage.login;
                    },
            ),
          ],
        ),
      ),
    );
  }
}
