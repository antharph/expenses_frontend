import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_page.dart';
import '../../auth/application/session_notifier.dart';

class _DeleteAccountResult {
  const _DeleteAccountResult({
    required this.confirmed,
    this.password,
  });

  final bool confirmed;
  final String? password;
}

Future<void> confirmAndDeleteAccount(
  BuildContext context,
  WidgetRef ref, {
  required bool passwordAuthEnabled,
}) async {
  final result = await showDialog<_DeleteAccountResult>(
    context: context,
    builder: (dialogContext) => _DeleteAccountDialog(
      passwordAuthEnabled: passwordAuthEnabled,
    ),
  );

  if (result == null || !result.confirmed || !context.mounted) {
    return;
  }

  final error = await ref.read(sessionProvider.notifier).deleteAccount(
        password: result.password,
      );

  if (!context.mounted) {
    return;
  }

  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
    return;
  }

  ref.read(authPageProvider.notifier).state = AuthPage.login;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({
    required this.passwordAuthEnabled,
  });

  final bool passwordAuthEnabled;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    if (!widget.passwordAuthEnabled) {
      return true;
    }
    return _passwordController.text.isNotEmpty;
  }

  void _confirm() {
    if (!_canConfirm) {
      return;
    }

    Navigator.of(context).pop(
      _DeleteAccountResult(
        confirmed: true,
        password: widget.passwordAuthEnabled
            ? _passwordController.text
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Delete account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This cannot be undone. Your account and sign-in access will be permanently removed.',
            style: theme.textTheme.bodyMedium,
          ),
          if (widget.passwordAuthEnabled) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirm(),
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
                const _DeleteAccountResult(confirmed: false),
              ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canConfirm ? _confirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}
