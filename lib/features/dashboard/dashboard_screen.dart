import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/application/auth_page.dart';
import '../auth/application/session_notifier.dart';
import 'application/dashboard_expense_summary_provider.dart';
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
                : SizedBox(height: MediaQuery.sizeOf(context).height, width: 0),
          ),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: _railIndex == 0
                      ? const _DashboardHome()
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

class _DashboardHome extends ConsumerWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardExpenseSummaryProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: summaryAsync.when(
        data: (summary) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TodayTotalHeader(total: summary.todayTotal),
              const SizedBox(height: 24),
              Text(
                'Last 7 days',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: _DailyExpenseBarChart(summary: summary),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  ref.invalidate(dashboardExpenseSummaryProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayTotalHeader extends StatelessWidget {
  const _TodayTotalHeader({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Today's total",
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(currency.format(total), style: theme.textTheme.headlineMedium),
      ],
    );
  }
}

class _DailyExpenseBarChart extends StatelessWidget {
  const _DailyExpenseBarChart({required this.summary});

  final DashboardExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = summary.dailyTotals.map((e) => e.total).toList();
    final maxExpense = totals.isEmpty ? 0.0 : totals.reduce(math.max);
    final maxY = maxExpense <= 0 ? 1.0 : maxExpense * 1.15;

    final dayLabels = DateFormat.E();

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final i = group.x.toInt();
              if (i < 0 || i >= summary.dailyTotals.length) {
                return null;
              }
              final d = summary.dailyTotals[i];
              final currency = NumberFormat.currency(
                symbol: r'$',
                decimalDigits: 2,
              );
              return BarTooltipItem(
                '${DateFormat.MMMd().format(d.day)}\n${currency.format(d.total)}',
                theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                    ) ??
                    const TextStyle(),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY <= 4 ? 1 : null,
              getTitlesWidget: (value, meta) {
                if (value > meta.max) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value == value.roundToDouble()
                        ? value.toInt().toString()
                        : value.toStringAsFixed(1),
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.end,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= summary.dailyTotals.length) {
                  return const SizedBox.shrink();
                }
                final d = summary.dailyTotals[i].day;
                final isToday =
                    d.year == DateTime.now().year &&
                    d.month == DateTime.now().month &&
                    d.day == DateTime.now().day;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    dayLabels.format(d),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isToday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY <= 4 ? 1 : maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < summary.dailyTotals.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: summary.dailyTotals[i].total,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
