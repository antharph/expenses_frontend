import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_page.dart';
import '../../auth/application/session_notifier.dart';

/// Overflow account menu — sign out is tucked behind the ⋮ icon, not primary nav.
class SignOutMenuButton extends ConsumerWidget {
  const SignOutMenuButton({super.key});

  Future<void> _confirmAndSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to use the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await ref.read(sessionProvider.notifier).logout();
    if (!context.mounted) {
      return;
    }
    ref.read(authPageProvider.notifier).state = AuthPage.login;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_AccountMenuAction>(
      tooltip: 'Account',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _AccountMenuAction.signOut:
            _confirmAndSignOut(context, ref);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _AccountMenuAction.signOut,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_outlined),
              SizedBox(width: 12),
              Text('Sign out'),
            ],
          ),
        ),
      ],
    );
  }
}

enum _AccountMenuAction { signOut }
