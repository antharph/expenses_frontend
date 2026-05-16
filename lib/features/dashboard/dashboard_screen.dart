import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/application/auth_page.dart';
import '../auth/application/session_notifier.dart';
import 'application/dashboard_expense_summary_provider.dart';
import '../expenses/presentation/expenses_screen.dart';

/// Ceiling for bar chart axis only (not data).
double _niceChartCeiling(double dataMax, {double headroom = 1.08}) {
  if (dataMax <= 0) return 1;
  final raw = dataMax * headroom;
  final exponent = math
      .pow(10.0, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final n = raw / exponent;
  final niceFrac = n <= 1
      ? 1.0
      : n <= 2
      ? 2.0
      : n <= 5
      ? 5.0
      : 10.0;
  return niceFrac * exponent;
}

String _axisMoneyLabel(double value) {
  if (value.abs() < 1e-6) {
    return r'0';
  }
  final isIntegerLike = value == value.roundToDouble();
  if (isIntegerLike) {
    return NumberFormat.currency(symbol: r'', decimalDigits: 0).format(value);
  }
  return NumberFormat.currency(symbol: r'', decimalDigits: 0).format(value);
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _railIndex = 0;
  bool _railExpanded = true;

  static const Duration _railAnimationDuration = Duration(milliseconds: 250);

  /// Below this width an expanded rail feels “full width”; taps on the dimmed
  /// overlay collapse it so sheet content stays readable.
  static const double _compactRailWidthBreakpoint = 900;

  IconButtonThemeData _flatNavIconTheme(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = IconButton.styleFrom(
      foregroundColor: scheme.onSurfaceVariant,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      minimumSize: const Size(48, 48),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    return IconButtonThemeData(style: style);
  }

  Future<void> _logout() async {
    await ref.read(sessionProvider.notifier).logout();
    if (!mounted) {
      return;
    }
    ref.read(authPageProvider.notifier).state = AuthPage.login;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compactRail = width < _compactRailWidthBreakpoint;

    Widget body = _railIndex == 0
        ? const _DashboardHome()
        : const ExpensesScreen();

    if (compactRail && _railExpanded) {
      body = Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          body,
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _railExpanded = false),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.12)),
            ),
          ),
        ],
      );
    }

    final railCollapseButton = Tooltip(
      message: 'Collapse sidebar',
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => setState(() => _railExpanded = false),
      ),
    );

    final railExpandButton = Tooltip(
      message: 'Expand sidebar',
      child: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => setState(() => _railExpanded = true),
      ),
    );

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IconButtonTheme(
            data: _flatNavIconTheme(context),
            child: AnimatedSize(
              duration: _railAnimationDuration,
              curve: Curves.easeInOutCubic,
              alignment: Alignment.centerLeft,
              child: _railExpanded
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        NavigationRail(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLow
                              .withValues(alpha: 0.82),
                          selectedIndex: _railIndex,
                          onDestinationSelected: (index) {
                            if (index == 2) {
                              _logout();
                              return;
                            }
                            setState(() {
                              _railIndex = index;
                              if (compactRail) {
                                _railExpanded = false;
                              }
                            });
                          },
                          labelType: NavigationRailLabelType.all,
                          leading: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: railCollapseButton,
                          ),
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
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Material(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLow
                              .withValues(alpha: 0.82),
                          child: SizedBox(
                            width: 56,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: railExpandButton,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Shared horizontal inset so section headers and chart copy line up visually.
const double _kDashboardContentGutter = 24;

class _DashboardHome extends ConsumerWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardExpenseSummaryProvider);
    const topPad = 12.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kDashboardContentGutter,
        topPad,
        _kDashboardContentGutter,
        _kDashboardContentGutter,
      ),
      child: summaryAsync.when(
        data: (summary) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TodayTotalHeader(total: summary.todayTotal),
              const SizedBox(height: 40),
              Text(
                'Last 7 days',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
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
    final currency = NumberFormat.currency(symbol: r'', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's total",
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          currency.format(total),
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _DailyExpenseBarChart extends StatelessWidget {
  const _DailyExpenseBarChart({required this.summary});

  final DashboardExpenseSummary summary;

  static const _gridDivisions = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = summary.dailyTotals.map((e) => e.total).toList();
    final maxExpense = totals.isEmpty ? 0.0 : totals.reduce(math.max);
    final chartMaxY = maxExpense <= 0 ? 1.0 : _niceChartCeiling(maxExpense);
    final horizontalInterval = chartMaxY / _gridDivisions;

    final dayLabels = DateFormat.E();

    return BarChart(
      BarChartData(
        maxY: chartMaxY,
        alignment: BarChartAlignment.spaceAround,
        groupsSpace: 14,
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          longPressDuration: Duration.zero,
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            tooltipMargin: 8,
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final i = group.x.toInt();
              if (i < 0 || i >= summary.dailyTotals.length) {
                return null;
              }
              final d = summary.dailyTotals[i];
              final currency = NumberFormat.currency(
                symbol: r'',
                decimalDigits: 2,
              );
              return BarTooltipItem(
                '${DateFormat.MMMd().format(d.day)}\n'
                '${currency.format(d.total)}',
                theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
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
              reservedSize: 44,
              interval: horizontalInterval,
              maxIncluded: false,
              minIncluded: true,
              getTitlesWidget: (value, meta) {
                if (value > meta.max + 1e-6 || value < -1e-9) {
                  return const SizedBox.shrink();
                }
                final labelStyle = theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                );

                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    _axisMoneyLabel(value),
                    style: labelStyle,
                    textAlign: TextAlign.start,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= summary.dailyTotals.length) {
                  return const SizedBox.shrink();
                }
                final d = summary.dailyTotals[i].day;
                final now = DateTime.now();
                final isToday =
                    d.year == now.year &&
                    d.month == now.month &&
                    d.day == now.day;

                final labelStyle = theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                );

                return SideTitleWidget(
                  meta: meta,
                  space: 0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      dayLabels.format(d),
                      style: labelStyle,
                      textAlign: TextAlign.center,
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
          horizontalInterval: horizontalInterval,
          checkToShowHorizontalLine: (value) {
            if (value < -1e-9 || value > chartMaxY + 1e-6) {
              return false;
            }
            if ((value - chartMaxY).abs() < horizontalInterval * 0.015) {
              return false;
            }
            final n = value / horizontalInterval;
            return (n - n.round()).abs() < 0.02;
          },
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.32),
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
