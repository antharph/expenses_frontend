import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/application/auth_page.dart';
import '../auth/application/session_notifier.dart';
import '../budget/application/budget_providers.dart';
import '../budget/presentation/budget_history_screen.dart';
import '../budget/presentation/budget_progress_card.dart';
import '../budget/presentation/create_budget_sheet.dart';
import 'application/dashboard_expense_summary_provider.dart';
import 'domain/expense_week.dart';
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

/// Side-by-side spending analytics and budgets when content is wide enough.
const double _kDashboardTwoColumnBreakpoint = 840;

const double _kDashboardSectionGap = 40;

class _DashboardHome extends ConsumerStatefulWidget {
  const _DashboardHome();

  @override
  ConsumerState<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends ConsumerState<_DashboardHome> {
  late final PageController _weekPageController;

  @override
  void initState() {
    super.initState();
    _weekPageController = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    super.dispose();
  }

  void _onWeekPageChanged(int index) {
    if (index == 1) {
      return;
    }
    final selected = ref.read(dashboardSelectedWeekProvider);
    final target = index == 0
        ? ExpenseWeek.previous(selected.year, selected.week)
        : ExpenseWeek.next(selected.year, selected.week);
    ref.read(dashboardSelectedWeekProvider.notifier).state = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_weekPageController.hasClients) {
        return;
      }
      _weekPageController.jumpToPage(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    const topPad = 12.0;
    final selected = ref.watch(dashboardSelectedWeekProvider);
    final previous = ExpenseWeek.previous(selected.year, selected.week);
    final next = ExpenseWeek.next(selected.year, selected.week);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kDashboardContentGutter,
        topPad,
        _kDashboardContentGutter,
        _kDashboardContentGutter,
      ),
      child: PageView(
        controller: _weekPageController,
        onPageChanged: _onWeekPageChanged,
        children: [
          _WeekDashboardPage(
            key: ValueKey('week-${previous.year}-${previous.week}'),
            weekKey: previous,
          ),
          _WeekDashboardPage(
            key: ValueKey('week-${selected.year}-${selected.week}'),
            weekKey: selected,
          ),
          _WeekDashboardPage(
            key: ValueKey('week-${next.year}-${next.week}'),
            weekKey: next,
          ),
        ],
      ),
    );
  }
}

class _WeekDashboardPage extends ConsumerWidget {
  const _WeekDashboardPage({super.key, required this.weekKey});

  final ExpenseWeekKey weekKey;

  void _toggleCategoryFilter(WidgetRef ref, String label) {
    final notifier = ref.read(
      dashboardCategoryFilterProvider(weekKey).notifier,
    );
    notifier.state = notifier.state == label ? null : label;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardExpenseSummaryProvider(weekKey));
    final selectedCategory = ref.watch(
      dashboardCategoryFilterProvider(weekKey),
    );

    return summaryAsync.when(
      data: (summary) {
        final display = summary.filteredView(categoryLabel: selectedCategory);

        final spendingAnalytics = _DashboardSpendingAnalytics(
          display: display,
          summary: summary,
          selectedCategory: selectedCategory,
          onClearCategoryFilter: () {
            ref
                    .read(
                      dashboardCategoryFilterProvider(weekKey).notifier,
                    )
                    .state =
                null;
          },
        );

        final categoryBreakdown = _DashboardCategoryBreakdown(
          summary: summary,
          selectedCategory: selectedCategory,
          onCategorySelected: (label) => _toggleCategoryFilter(ref, label),
        );

        const budgets = _BudgetProgressSection();

        return LayoutBuilder(
          builder: (context, constraints) {
            final useTwoColumns =
                constraints.maxWidth >= _kDashboardTwoColumnBreakpoint;

            if (useTwoColumns) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          spendingAnalytics,
                          const SizedBox(height: _kDashboardSectionGap),
                          categoryBreakdown,
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(flex: 2, child: budgets),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  spendingAnalytics,
                  const SizedBox(height: _kDashboardSectionGap),
                  categoryBreakdown,
                  const SizedBox(height: _kDashboardSectionGap),
                  budgets,
                ],
              ),
            );
          },
        );
      },
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
                ref.invalidate(dashboardExpenseSummaryProvider(weekKey));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSpendingAnalytics extends StatelessWidget {
  const _DashboardSpendingAnalytics({
    required this.display,
    required this.summary,
    required this.selectedCategory,
    required this.onClearCategoryFilter,
  });

  final DashboardExpenseSummary display;
  final DashboardExpenseSummary summary;
  final String? selectedCategory;
  final VoidCallback onClearCategoryFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeekTotalHeader(
          total: display.weekTotal,
          categoryLabel: selectedCategory,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: selectedCategory != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    _CategoryFilterBanner(
                      categoryLabel: selectedCategory!,
                      onClear: onClearCategoryFilter,
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: _kDashboardSectionGap),
        _WeekRangeSubtitle(
          startDate: summary.startDate,
          endDate: summary.endDate,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 248,
          child: _DailyExpenseBarChart(summary: display),
        ),
      ],
    );
  }
}

class _DashboardCategoryBreakdown extends StatelessWidget {
  const _DashboardCategoryBreakdown({
    required this.summary,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final DashboardExpenseSummary summary;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'By category',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a slice to filter the chart above',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _CategoryExpensePieChart(
          summary: summary,
          selectedCategory: selectedCategory,
          onCategorySelected: onCategorySelected,
        ),
      ],
    );
  }
}

class _BudgetProgressSection extends ConsumerWidget {
  const _BudgetProgressSection();

  void _showCreateBudgetSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const CreateBudgetSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(dashboardBudgetsProvider);
    final theme = Theme.of(context);

    return budgetsAsync.when(
      data: (budgets) {
        if (budgets.isEmpty) {
          return _EmptyBudgetPrompt(
            onCreateBudget: () => _showCreateBudgetSheet(context),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budgets',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a card for period history',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _showCreateBudgetSheet(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create budget'),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < budgets.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              BudgetProgressCard(
                budget: budgets[i],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BudgetHistoryScreen(
                        budgetId: budgets[i].id,
                        budgetName: budgets[i].name,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _EmptyBudgetPrompt extends StatelessWidget {
  const _EmptyBudgetPrompt({required this.onCreateBudget});

  final VoidCallback onCreateBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              'No budgets yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a budget to track what remains for each pay period.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateBudget,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create budget'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekTotalHeader extends StatelessWidget {
  const _WeekTotalHeader({required this.total, this.categoryLabel});

  final double total;
  final String? categoryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: r'', decimalDigits: 0);
    final filtered = categoryLabel != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          filtered ? 'Total · $categoryLabel' : 'Total',
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
            color: filtered
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _CategoryFilterBanner extends StatelessWidget {
  const _CategoryFilterBanner({
    required this.categoryLabel,
    required this.onClear,
  });

  final String categoryLabel;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'Showing $categoryLabel only',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              child: Text('Clear', style: TextStyle(color: scheme.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekRangeSubtitle extends StatelessWidget {
  const _WeekRangeSubtitle({required this.startDate, required this.endDate});

  final DateTime startDate;
  final DateTime endDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range =
        '${DateFormat.MMMd().format(startDate)} – '
        '${DateFormat.MMMd().format(endDate)}';

    return Row(
      children: [
        Expanded(
          child: Text(
            range,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Icon(
          Icons.swipe_rounded,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
        ),
      ],
    );
  }
}

class _DailyExpenseBarChart extends StatelessWidget {
  const _DailyExpenseBarChart({required this.summary});

  final DashboardExpenseSummary summary;

  static const _gridDivisions = 3;

  static const double _futurePlaceholderFraction = 0.045;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = summary.dailyTotals
        .where((e) => !e.isFuturePlaceholder)
        .map((e) => e.total)
        .toList();
    final maxExpense = totals.isEmpty ? 0.0 : totals.reduce(math.max);
    final chartMaxY = maxExpense <= 0 ? 1.0 : _niceChartCeiling(maxExpense);
    final horizontalInterval = chartMaxY / _gridDivisions;
    final placeholderY = chartMaxY * _futurePlaceholderFraction;

    final dayLabels = DateFormat.E();
    final scheme = theme.colorScheme;

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
              if (d.isFuturePlaceholder) {
                return null;
              }
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= summary.dailyTotals.length) {
                  return const SizedBox.shrink();
                }
                final entry = summary.dailyTotals[i];
                final d = entry.day;
                final isToday = entry.isToday;

                final labelStyle = theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                  color: isToday ? scheme.primary : scheme.onSurfaceVariant,
                );

                return SideTitleWidget(
                  meta: meta,
                  space: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dayLabels.format(d),
                        style: labelStyle,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(
                        height: isToday ? 6 : 0,
                        child: isToday
                            ? Center(
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
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
        barGroups: List.generate(summary.dailyTotals.length, (i) {
          final entry = summary.dailyTotals[i];
          final isFuture = entry.isFuturePlaceholder;
          final isToday = entry.isToday;
          final rodY = isFuture
              ? placeholderY
              : entry.total <= 0
              ? 0.0
              : entry.total;
          final rodColor = isFuture
              ? scheme.outlineVariant.withValues(alpha: 0.35)
              : isToday
              ? scheme.tertiary
              : scheme.primary;

          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: rodY,
                width: 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                color: rodColor,
              ),
            ],
          );
        }),
      ),
    );
  }
}

List<Color> _pieChartColors(ColorScheme scheme, int count) {
  final base = <Color>[
    scheme.primary,
    scheme.secondary,
    scheme.tertiary,
    scheme.primaryContainer,
    scheme.secondaryContainer,
    scheme.tertiaryContainer,
    scheme.error,
    scheme.inversePrimary,
  ];
  if (count <= base.length) {
    return base.sublist(0, count);
  }
  return List.generate(count, (i) => base[i % base.length]);
}

class _CategoryExpensePieChart extends StatelessWidget {
  const _CategoryExpensePieChart({
    required this.summary,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final DashboardExpenseSummary summary;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;

  void _onPieTouch(
    FlTouchEvent event,
    PieTouchResponse? response,
    List<CategoryExpenseTotal> totals,
  ) {
    if (event is! FlTapUpEvent || response == null) {
      return;
    }
    final index = response.touchedSection?.touchedSectionIndex;
    if (index == null || index < 0 || index >= totals.length) {
      return;
    }
    onCategorySelected(totals[index].label);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = summary.categoryTotals;
    final grandTotal = totals.fold<double>(0, (sum, e) => sum + e.total);

    if (grandTotal <= 0) {
      return SizedBox(
        width: double.infinity,
        height: 200,
        child: Center(
          child: Text(
            'No expenses this week',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final colors = _pieChartColors(theme.colorScheme, totals.length);
    final currency = NumberFormat.currency(symbol: r'', decimalDigits: 0);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Expense breakdown by category. Tap a slice to filter.',
          child: SizedBox(
            width: double.infinity,
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 44,
                pieTouchData: PieTouchData(
                  enabled: true,
                  touchCallback: (event, response) =>
                      _onPieTouch(event, response, totals),
                ),
                sections: [
                  for (var i = 0; i < totals.length; i++)
                    _pieSection(
                      theme: theme,
                      scheme: scheme,
                      entry: totals[i],
                      color: colors[i],
                      grandTotal: grandTotal,
                      selected: totals[i].label == selectedCategory,
                      dimmed:
                          selectedCategory != null &&
                          totals[i].label != selectedCategory,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (var i = 0; i < totals.length; i++)
              _CategoryLegendChip(
                color: colors[i],
                label: totals[i].label,
                amount: currency.format(totals[i].total),
                selected: totals[i].label == selectedCategory,
                onTap: () => onCategorySelected(totals[i].label),
              ),
          ],
        ),
      ],
    );
  }

  PieChartSectionData _pieSection({
    required ThemeData theme,
    required ColorScheme scheme,
    required CategoryExpenseTotal entry,
    required Color color,
    required double grandTotal,
    required bool selected,
    required bool dimmed,
  }) {
    final share = entry.total / grandTotal;
    final baseRadius = 52.0;
    final radius = selected ? baseRadius + 6 : baseRadius;
    final sectionColor = dimmed ? color.withValues(alpha: 0.35) : color;

    return PieChartSectionData(
      value: entry.total,
      color: sectionColor,
      radius: radius,
      showTitle: share >= 0.08,
      title: '${(share * 100).round()}%',
      titleStyle: theme.textTheme.labelSmall?.copyWith(
        color: scheme.onPrimary,
        fontWeight: FontWeight.w600,
      ),
      borderSide: selected
          ? BorderSide(color: scheme.onSurface, width: 2.5)
          : BorderSide.none,
    );
  }
}

class _CategoryLegendChip extends StatelessWidget {
  const _CategoryLegendChip({
    required this.color,
    required this.label,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final String amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '$label · $amount',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
