import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_errors.dart';
import '../../auth/application/session_notifier.dart';
import '../application/budget_providers.dart';
import '../data/budgets_api.dart';
import '../domain/budget_log_entry.dart';
import '../domain/budget_progress.dart';
import 'create_budget_sheet.dart';

const double _kHistoryGutter = 20;

class BudgetHistoryScreen extends ConsumerStatefulWidget {
  const BudgetHistoryScreen({
    super.key,
    required this.budget,
    required this.budgets,
  });

  final BudgetProgress budget;
  final List<BudgetProgress> budgets;

  @override
  ConsumerState<BudgetHistoryScreen> createState() =>
      _BudgetHistoryScreenState();
}

class _BudgetHistoryScreenState extends ConsumerState<BudgetHistoryScreen> {
  late BudgetProgress _budget;
  late List<BudgetProgress> _budgets;
  bool _deleting = false;
  bool _finalizing = false;

  static final _currency = NumberFormat.currency(symbol: r'', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _budget = widget.budget;
    _budgets = widget.budgets;
  }

  String _periodLabel(BudgetLogEntry entry) {
    final start = DateFormat.MMMd().format(entry.startDate);
    if (entry.endDate == null) {
      return '$start – ongoing';
    }
    final end = DateFormat.MMMd().format(entry.endDate!);
    return '$start – $end';
  }

  List<BudgetLogEntry> _sortedLogs(List<BudgetLogEntry> logs) {
    final sorted = List<BudgetLogEntry>.from(logs)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return sorted;
  }

  Future<void> _refreshLogs() async {
    ref.invalidate(budgetLogsProvider(_budget.id));
    await ref.read(budgetLogsProvider(_budget.id).future);
  }

  Future<void> _showEditCategoriesSheet() async {
    final updatedBudget = await showModalBottomSheet<BudgetProgress>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          EditBudgetCategoriesSheet(budget: _budget, existingBudgets: _budgets),
    );

    if (updatedBudget == null || !mounted) {
      return;
    }

    setState(() {
      _budget = updatedBudget;
      _budgets = [
        for (final budget in _budgets)
          if (budget.id == updatedBudget.id) updatedBudget else budget,
      ];
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete budget'),
        content: Text(
          'Remove "${_displayLabel(_budget.name)}"? Period history will be deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final token = ref.read(sessionProvider).valueOrNull?.token;
    if (token == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not signed in.')));
      return;
    }

    setState(() => _deleting = true);

    try {
      await ref
          .read(budgetsApiProvider)
          .deleteBudget(token: token, budgetId: _budget.id);
      ref.invalidate(dashboardBudgetsProvider);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(formatApiError(error))));
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Future<void> _confirmFinalizeManual() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalize period'),
        content: Text(
          'Close the current period for "${_displayLabel(_budget.name)}"? Spending will be saved to history and a new manual period will start tomorrow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final token = ref.read(sessionProvider).valueOrNull?.token;
    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not signed in.')));
      return;
    }

    setState(() => _finalizing = true);

    try {
      final updatedBudget = await ref
          .read(budgetsApiProvider)
          .finalizeManualBudget(token: token, budgetId: _budget.id);
      ref.invalidate(dashboardBudgetsProvider);
      ref.invalidate(budgetLogsProvider(_budget.id));

      if (!mounted) {
        return;
      }

      setState(() {
        _budget = updatedBudget;
        _budgets = [
          for (final budget in _budgets)
            if (budget.id == updatedBudget.id) updatedBudget else budget,
        ];
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Budget period finalized.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(formatApiError(error))));
    } finally {
      if (mounted) {
        setState(() => _finalizing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(budgetLogsProvider(_budget.id));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_displayLabel(_budget.name)),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            enabled: !_deleting && !_finalizing,
            onSelected: (value) {
              if (value == 'finalize') {
                unawaited(_confirmFinalizeManual());
              }
              if (value == 'edit_categories') {
                unawaited(_showEditCategoriesSheet());
              }
              if (value == 'delete') {
                _confirmDelete();
              }
            },
            itemBuilder: (context) => [
              if (_budget.isManual)
                const PopupMenuItem<String>(
                  value: 'finalize',
                  child: Text('Finalize current period'),
                ),
              const PopupMenuItem<String>(
                value: 'edit_categories',
                child: Text('Edit categories'),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(
                  'Delete budget',
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          logsAsync.when(
            data: (logs) {
              if (logs.isEmpty) {
                return const _BudgetHistoryEmptyState();
              }

              final sorted = _sortedLogs(logs);
              final current = sorted.first;
              final previous = sorted.length > 1 ? sorted[1] : null;
              final older =
                  sorted.length > 2 ? sorted.sublist(2) : const <BudgetLogEntry>[];

              return RefreshIndicator(
                onRefresh: _refreshLogs,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    _kHistoryGutter,
                    8,
                    _kHistoryGutter,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  children: [
                    _PeriodSummaryCard(
                      sectionLabel: 'Current period',
                      periodLabel: _periodLabel(current),
                      entry: current,
                      formatAmount: _currency.format,
                    ),
                    if (previous != null) ...[
                      const SizedBox(height: 28),
                      _PeriodSummaryCard(
                        sectionLabel: 'Previous period',
                        periodLabel: _periodLabel(previous),
                        entry: previous,
                        formatAmount: _currency.format,
                      ),
                    ],
                    if (older.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _SectionHeader(label: 'Older periods'),
                      const SizedBox(height: 12),
                      for (var i = 0; i < older.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _PastPeriodRow(
                          periodLabel: _periodLabel(older[i]),
                          entry: older[i],
                          formatAmount: _currency.format,
                        ),
                      ],
                    ],
                  ],
                ),
              );
            },
            loading: () => const _BudgetHistorySkeleton(),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(_kHistoryGutter),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 40,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load history',
                      style: theme.textTheme.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatApiError(error),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _deleting
                          ? null
                          : () {
                              ref.invalidate(budgetLogsProvider(_budget.id));
                            },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_deleting || _finalizing)
            Positioned.fill(
              child: ColoredBox(
                color: scheme.scrim.withValues(alpha: 0.35),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hero card for a budget period summary (current or previous).
class _PeriodSummaryCard extends StatelessWidget {
  const _PeriodSummaryCard({
    required this.sectionLabel,
    required this.periodLabel,
    required this.entry,
    required this.formatAmount,
  });

  final String sectionLabel;
  final String periodLabel;
  final BudgetLogEntry entry;
  final String Function(num) formatAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isTrackingOnly = entry.isTrackingOnly;
    final allocated = entry.allocatedAmount ?? 0;
    final remaining = allocated - entry.spentAmount;
    final isOver = !isTrackingOnly && remaining < 0;
    final barColor = isOver ? scheme.error : scheme.primary;
    final progressFraction = isTrackingOnly || allocated <= 0
        ? 0.0
        : (remaining / allocated).clamp(0.0, 1.0);

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sectionLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              periodLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isTrackingOnly
                  ? 'Total spent'
                  : isOver
                      ? 'Over by'
                      : 'Remaining',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isTrackingOnly
                  ? formatAmount(entry.spentAmount)
                  : formatAmount(isOver ? remaining.abs() : remaining),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.05,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isOver ? scheme.error : scheme.onSurface,
              ),
            ),
            if (!isTrackingOnly) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressFraction,
                  minHeight: 8,
                  backgroundColor: scheme.outlineVariant.withValues(alpha: 0.3),
                  color: barColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatAmount(entry.spentAmount)} spent of ${formatAmount(allocated)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact row for closed periods — one summary line, no repeated metric blocks.
class _PastPeriodRow extends StatelessWidget {
  const _PastPeriodRow({
    required this.periodLabel,
    required this.entry,
    required this.formatAmount,
  });

  final String periodLabel;
  final BudgetLogEntry entry;
  final String Function(num) formatAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isTrackingOnly = entry.isTrackingOnly;

    final subtitle = isTrackingOnly
        ? '${formatAmount(entry.spentAmount)} spent'
        : '${formatAmount(entry.spentAmount)} spent · ${formatAmount(entry.rolloverAmount ?? 0)} rolled over';

    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    periodLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (!isTrackingOnly)
              Text(
                formatAmount(entry.allocatedAmount ?? 0),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _BudgetHistoryEmptyState extends StatelessWidget {
  const _BudgetHistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_kHistoryGutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_outlined,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'No period history yet',
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Pay period summaries will appear here after spending is tracked.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetHistorySkeleton extends StatelessWidget {
  const _BudgetHistorySkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        _kHistoryGutter,
        8,
        _kHistoryGutter,
        24,
      ),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bone(width: 100, height: 14),
                const SizedBox(height: 8),
                _Bone(width: 140, height: 18),
                const SizedBox(height: 20),
                _Bone(width: 72, height: 12),
                const SizedBox(height: 6),
                _Bone(width: 120, height: 36),
                const SizedBox(height: 16),
                _Bone(width: double.infinity, height: 8, radius: 6),
                const SizedBox(height: 8),
                _Bone(width: 160, height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({required this.width, required this.height, this.radius = 6});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
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
