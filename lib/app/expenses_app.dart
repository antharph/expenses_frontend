import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_page.dart';
import '../features/auth/application/session_notifier.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/dashboard/dashboard_screen.dart';

class ExpensesApp extends ConsumerWidget {
  const ExpensesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final page = ref.watch(authPageProvider);

    return MaterialApp(
      title: 'Expenses',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006A6A)),
      ),
      home: session.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Something went wrong while starting the app.\n\n$error',
              ),
            ),
          ),
        ),
        data: (user) {
          if (user != null) {
            return const _DashboardShell();
          }
          return page == AuthPage.login
              ? const LoginScreen()
              : const RegisterScreen();
        },
      ),
    );
  }
}

/// Paints notch / status-bar insets with the scaffold background color so they
/// are not black, then applies [SafeArea] around the dashboard.
class _DashboardShell extends StatelessWidget {
  const _DashboardShell();

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).scaffoldBackgroundColor;

    return ColoredBox(
      color: surface,
      child: const SafeArea(
        child: DashboardScreen(),
      ),
    );
  }
}
