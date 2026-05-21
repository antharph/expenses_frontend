import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../expenses/domain/expense_category.dart';
import '../domain/budget_progress.dart';

class BudgetProgressCard extends StatelessWidget {
  const BudgetProgressCard({super.key, required this.budget, this.onTap});

  final BudgetProgress budget;
  final VoidCallback? onTap;

  static final _currencyWhole = NumberFormat.currency(
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

  String _contextSubtitle() {
    final parts = <String>[_periodLabel()];
    if (budget.rolloverEnabled) {
      parts.add('Rollover on');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final barColor = budget.isOverBudget ? scheme.error : scheme.primary;
    final remainingLabel = budget.isOverBudget
        ? _currencyWhole.format(budget.remainingAmount.abs())
        : _currencyWhole.format(budget.remainingAmount);
    final spentLabel = _currencyWhole.format(budget.spentAmount);
    final allocatedLabel = _currencyWhole.format(budget.allocatedAmount);

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayLabel(budget.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _contextSubtitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ],
              ),
              if (budget.categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                _CategoryRow(categories: budget.categories),
              ],
              const SizedBox(height: 20),
              Text(
                budget.isOverBudget ? 'Over by' : 'Remaining',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                remainingLabel,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: budget.isOverBudget ? scheme.error : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: budget.progressFraction,
                  minHeight: 8,
                  backgroundColor: scheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                  color: barColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$spentLabel spent of $allocatedLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact category chips — avoids repeating long comma-separated labels.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.categories});

  final List<ExpenseCategory> categories;

  static const _maxVisible = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = categories.take(_maxVisible);
    final overflow = categories.length - _maxVisible;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final category in visible)
          _CategoryMicroChip(
            label: category.name,
            accent: _categoryAccent(scheme, category.name),
          ),
        if (overflow > 0)
          _CategoryMicroChip(
            label: '+$overflow more',
            accent: scheme.outline,
            muted: true,
          ),
      ],
    );
  }
}

class _CategoryMicroChip extends StatelessWidget {
  const _CategoryMicroChip({
    required this.label,
    required this.accent,
    this.muted = false,
  });

  final String label;
  final Color accent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: muted
            ? scheme.surfaceContainerLow
            : accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!muted) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            _displayLabel(label),
            style: theme.textTheme.labelMedium?.copyWith(
              color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ],
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

Color _categoryAccent(ColorScheme scheme, String label) {
  final palette = [
    scheme.primary,
    scheme.secondary,
    scheme.tertiary,
    scheme.primaryContainer,
    scheme.secondaryContainer,
    scheme.tertiaryContainer,
  ];
  return palette[label.hashCode.abs() % palette.length];
}
