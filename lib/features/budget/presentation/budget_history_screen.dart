import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_errors.dart';
import '../../auth/application/session_notifier.dart';
import '../application/budget_providers.dart';
import '../data/budgets_api.dart';
import '../domain/budget_log_entry.dart';

class BudgetHistoryScreen extends ConsumerStatefulWidget {
  const BudgetHistoryScreen({
    super.key,
    required this.budgetId,
    required this.budgetName,
  });

  final int budgetId;
  final String budgetName;

  @override
  ConsumerState<BudgetHistoryScreen> createState() =>
      _BudgetHistoryScreenState();
}

class _BudgetHistoryScreenState extends ConsumerState<BudgetHistoryScreen> {
  bool _deleting = false;

  static final _currency = NumberFormat.currency(
    symbol: r'',
    decimalDigits: 0,
  );

  String _periodLabel(BudgetLogEntry entry) {
    final start = DateFormat.MMMd().format(entry.startDate);
    if (entry.endDate == null) {
      return '$start - ongoing';
    }
    final end = DateFormat.MMMd().format(entry.endDate!);
    return '$start - $end';
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete budget'),
        content: Text(
          'Remove "${widget.budgetName}"? Period history will be deleted. This cannot be undone.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in.')),
      );
      return;
    }

    setState(() => _deleting = true);

    try {
      await ref.read(budgetsApiProvider).deleteBudget(
            token: token,
            budgetId: widget.budgetId,
          );
      ref.invalidate(dashboardBudgetsProvider);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(budgetLogsProvider(widget.budgetId));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.budgetName),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            enabled: !_deleting,
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDelete();
              }
            },
            itemBuilder: (context) => [
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
                return Center(
                  child: Text(
                    'No budget history yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final entry = logs[index];
                  return _BudgetLogListTile(
                    periodLabel: _periodLabel(entry),
                    allocated: _currency.format(entry.allocatedAmount),
                    spent: _currency.format(entry.spentAmount),
                    rollover: _currency.format(entry.rolloverAmount),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _deleting
                          ? null
                          : () {
                              ref.invalidate(
                                budgetLogsProvider(widget.budgetId),
                              );
                            },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_deleting)
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

class _BudgetLogListTile extends StatelessWidget {
  const _BudgetLogListTile({
    required this.periodLabel,
    required this.allocated,
    required this.spent,
    required this.rollover,
  });

  final String periodLabel;
  final String allocated;
  final String spent;
  final String rollover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        periodLabel,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MetricLine(
              label: 'Allocated',
              value: allocated,
              labelStyle: detailStyle,
              valueStyle: valueStyle,
            ),
            const SizedBox(height: 4),
            _MetricLine(
              label: 'Spent',
              value: spent,
              labelStyle: detailStyle,
              valueStyle: valueStyle,
            ),
            const SizedBox(height: 4),
            _MetricLine(
              label: 'Rollover',
              value: rollover,
              labelStyle: detailStyle,
              valueStyle: valueStyle?.copyWith(color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        Text(value, style: valueStyle),
      ],
    );
  }
}
