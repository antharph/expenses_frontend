import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/budget_progress.dart';

class BudgetProgressCard extends StatelessWidget {
  const BudgetProgressCard({
    super.key,
    required this.budget,
    this.onTap,
  });

  final BudgetProgress budget;
  final VoidCallback? onTap;

  static final _currencyWhole = NumberFormat.currency(
    symbol: r'',
    decimalDigits: 0,
  );

  static final _currencyBreakdown = NumberFormat.currency(
    symbol: r'',
    decimalDigits: 0,
  );

  String _periodLabel() {
    final start = DateFormat.MMMd().format(budget.periodStart);
    if (budget.periodEnd == null) {
      return '$start – ongoing';
    }
    final end = DateFormat.MMMd().format(budget.periodEnd!);
    return '$start – $end';
  }

  String _breakdownLabel() {
    final base = _currencyBreakdown.format(budget.baseAmount);
    if (budget.rolloverAmount <= 0) {
      return '$base Base';
    }
    final rollover = _currencyBreakdown.format(budget.rolloverAmount);
    return '$base Base + $rollover Rollover';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final barColor = budget.isOverBudget ? scheme.error : scheme.primary;
    final remainingLabel = budget.remainingAmount < 0
        ? _currencyWhole.format(budget.remainingAmount.abs())
        : _currencyWhole.format(budget.remainingAmount);

    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                budget.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _periodLabel(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                budget.isOverBudget ? 'Over by' : 'Remaining',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                remainingLabel,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: budget.isOverBudget
                      ? scheme.error
                      : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: budget.progressFraction,
                  minHeight: 10,
                  backgroundColor: scheme.outlineVariant.withValues(
                    alpha: 0.35,
                  ),
                  color: barColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _breakdownLabel(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
