import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../budget/presentation/budgets_screen.dart';
import 'application/dashboard_expense_summary_provider.dart';
import 'domain/expense_week.dart';
import '../expenses/presentation/expenses_screen.dart';
import 'presentation/sign_out_menu_button.dart';

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
  int _navIndex = 0;
  bool _railExpanded = true;

  static const Duration _railAnimationDuration = Duration(milliseconds: 250);

  /// Phone-width layouts use bottom navigation instead of a persistent side rail.
  static const double _narrowShellBreakpoint = 600;

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

  Widget _tabBody(int index) {
    return switch (index) {
      0 => Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: const [SignOutMenuButton()],
        ),
        body: const _DashboardHome(),
      ),
      1 => const BudgetsScreen(),
      2 => const ExpensesScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useBottomNav = width < _narrowShellBreakpoint;
    final compactRail = width < _compactRailWidthBreakpoint;

    if (useBottomNav) {
      return Scaffold(
        body: _tabBody(_navIndex),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _navIndex,
          onDestinationSelected: (index) => setState(() => _navIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Budgets',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Expenses',
            ),
          ],
        ),
      );
    }

    Widget body = _tabBody(_navIndex);

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
                          selectedIndex: _navIndex,
                          onDestinationSelected: (index) {
                            setState(() {
                              _navIndex = index;
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
                              icon: Icon(Icons.account_balance_wallet_outlined),
                              selectedIcon: Icon(Icons.account_balance_wallet),
                              label: Text('Budgets'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.receipt_long_outlined),
                              selectedIcon: Icon(Icons.receipt_long),
                              label: Text('Expenses'),
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
const double _kDashboardContentGutter = 20;

const double _kDashboardSectionGap = 32;

/// Neutral chart container — elevation via border, not tinted cards.
class _DashboardChartSurface extends StatelessWidget {
  const _DashboardChartSurface({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding:
            padding ?? const EdgeInsets.fromLTRB(4, 12, 12, 4),
        child: child,
      ),
    );
  }
}

class _DashboardSectionHeader extends StatelessWidget {
  const _DashboardSectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

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

  static const Duration _weekPageAnimationDuration = Duration(milliseconds: 280);

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

  Future<void> _animateToAdjacentWeek({required bool previous}) async {
    if (!_weekPageController.hasClients) {
      return;
    }
    final targetPage = previous ? 0 : 2;
    await _weekPageController.animateToPage(
      targetPage,
      duration: _weekPageAnimationDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad =
        _kDashboardContentGutter + MediaQuery.paddingOf(context).bottom + 16;
    final selected = ref.watch(dashboardSelectedWeekProvider);
    final previous = ExpenseWeek.previous(selected.year, selected.week);
    final next = ExpenseWeek.next(selected.year, selected.week);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _kDashboardContentGutter,
        8,
        _kDashboardContentGutter,
        bottomPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WeekPagerBar(
            weekKey: selected,
            onPreviousWeek: () => _animateToAdjacentWeek(previous: true),
            onNextWeek: () => _animateToAdjacentWeek(previous: false),
          ),
          const SizedBox(height: 16),
          Expanded(
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

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              spendingAnalytics,
              const SizedBox(height: _kDashboardSectionGap),
              categoryBreakdown,
            ],
          ),
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
        _WeekHeroMetric(
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
                    const SizedBox(height: 12),
                    _CategoryFilterBanner(
                      categoryLabel: selectedCategory!,
                      onClear: onClearCategoryFilter,
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: _kDashboardSectionGap),
        const _DashboardSectionHeader(title: 'Daily spending'),
        const SizedBox(height: 12),
        _DashboardChartSurface(
          child: SizedBox(
            width: double.infinity,
            height: 232,
            child: _DailyExpenseBarChart(summary: display),
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DashboardSectionHeader(
          title: 'Categories',
          subtitle: 'Tap a slice to filter daily spending',
        ),
        const SizedBox(height: 12),
        _DashboardChartSurface(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: _CategoryExpensePieChart(
            summary: summary,
            selectedCategory: selectedCategory,
            onCategorySelected: onCategorySelected,
          ),
        ),
      ],
    );
  }
}

class _WeekPagerBar extends StatelessWidget {
  const _WeekPagerBar({
    required this.weekKey,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  final ExpenseWeekKey weekKey;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final start = ExpenseWeek.weekStart(weekKey.year, weekKey.week);
    final end = ExpenseWeek.weekEnd(weekKey.year, weekKey.week);
    final range =
        '${DateFormat.MMMd().format(start)} – ${DateFormat.MMMd().format(end)}';
    final isCurrentWeek = ExpenseWeek.isCurrentCalendarWeek(
      weekKey.year,
      weekKey.week,
    );

    Widget navButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
    }) {
      return IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        icon: Icon(icon, size: 22),
      );
    }

    return Semantics(
      label:
          'Week of $range. Swipe horizontally or use arrows to change weeks.',
      child: Row(
        children: [
          navButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous week',
            onPressed: onPreviousWeek,
          ),
          Expanded(
            child: Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCurrentWeek) ...[
                      Text(
                        'This week',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      range,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swipe_rounded,
                          size: 14,
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Swipe for other weeks',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          navButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next week',
            onPressed: onNextWeek,
          ),
        ],
      ),
    );
  }
}

class _WeekHeroMetric extends StatelessWidget {
  const _WeekHeroMetric({required this.total, this.categoryLabel});

  final double total;
  final String? categoryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final currency = NumberFormat.currency(symbol: r'', decimalDigits: 0);
    final filtered = categoryLabel != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          filtered
              ? 'Week total · ${_displayLabel(categoryLabel!)}'
              : 'Week total',
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          currency.format(total),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.05,
            letterSpacing: -0.5,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: filtered ? scheme.primary : scheme.onSurface,
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
                  'Showing ${_displayLabel(categoryLabel)} only',
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
                  fontFeatures: const [FontFeature.tabularFigures()],
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
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
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
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
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

    final centerLabel = selectedCategory != null
        ? _displayLabel(selectedCategory!)
        : 'All categories';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Expense breakdown by category. Tap a slice to filter.',
          child: SizedBox(
            width: double.infinity,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 52,
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
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        centerLabel,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currency.format(grandTotal),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
          ? scheme.primaryContainer.withValues(alpha: 0.45)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayLabel(label),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    amount,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? scheme.onPrimaryContainer.withValues(alpha: 0.85)
                          : scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _displayLabel(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final alpha = trimmed.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (alpha.isNotEmpty && alpha == alpha.toUpperCase() && alpha.length > 2) {
    return trimmed
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
  return trimmed;
}
