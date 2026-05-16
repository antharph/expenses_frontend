import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/application/auth_page.dart';
import '../auth/application/session_notifier.dart';
import '../expenses/presentation/expenses_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _railIndex = 0;
  bool _railExpanded = true;

  static const Duration _railAnimationDuration = Duration(milliseconds: 250);

  Future<void> _logout() async {
    await ref.read(sessionProvider.notifier).logout();
    if (!mounted) {
      return;
    }
    ref.read(authPageProvider.notifier).state = AuthPage.login;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).valueOrNull;
    final name = session?.name ?? '';
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: _railAnimationDuration,
            curve: Curves.easeInOutCubic,
            alignment: Alignment.centerLeft,
            child: _railExpanded
                ? Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NavigationRail(
                            selectedIndex: _railIndex,
                            onDestinationSelected: (index) {
                              if (index == 2) {
                                _logout();
                                return;
                              }
                              setState(() => _railIndex = index);
                            },
                            labelType: NavigationRailLabelType.all,
                            destinations: const [
                              NavigationRailDestination(
                                icon: Icon(Icons.dashboard_outlined),
                                selectedIcon: Icon(Icons.dashboard),
                                label: Text('Dashboard'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.receipt_long_outlined),
                                selectedIcon: Icon(Icons.receipt_long),
                                label: Text('Expenses'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.logout_outlined),
                                selectedIcon: Icon(Icons.logout),
                                label: Text('Logout'),
                              ),
                            ],
                          ),
                          const VerticalDivider(width: 1),
                        ],
                      ),
                      Positioned(
                        right: -20,
                        top: topInset + 12,
                        child: FloatingActionButton.small(
                          heroTag: 'dashboard_rail_toggle',
                          tooltip: 'Collapse sidebar',
                          onPressed: () =>
                              setState(() => _railExpanded = false),
                          child: const Icon(Icons.chevron_left),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    height: MediaQuery.sizeOf(context).height,
                    width: 0,
                  ),
          ),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: _railIndex == 0
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              'Welcome${name.isEmpty ? '' : ', $name'}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                        )
                      : const ExpensesScreen(),
                ),
                if (!_railExpanded)
                  Positioned(
                    left: 16,
                    top: topInset + 12,
                    child: FloatingActionButton.small(
                      heroTag: 'dashboard_rail_toggle',
                      tooltip: 'Show sidebar',
                      onPressed: () => setState(() => _railExpanded = true),
                      child: const Icon(Icons.menu_rounded),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
