import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/expense.dart';
import '../domain/expense_date.dart';

void showExpenseDetailSheet(BuildContext context, Expense expense) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ExpenseDetailSheet(expense: expense),
  );
}

class ExpenseDetailSheet extends StatelessWidget {
  const ExpenseDetailSheet({super.key, required this.expense});

  final Expense expense;

  static final _currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
  static final _dateTimeFormat = DateFormat.yMMMd().add_jm();

  String _formatMoney(String raw) {
    final value = double.tryParse(raw);
    if (value == null) {
      return raw;
    }
    return _currency.format(value);
  }

  String _formatTransactionDateTime() {
    final raw = expense.transactionAtIso ?? expense.dateIso;
    if (raw.trim().isEmpty) {
      return '—';
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return _dateTimeFormat.format(parsed.toLocal());
    }

    final day = expenseLocalDay(raw);
    if (day != null) {
      return DateFormat.yMMMd().format(day);
    }

    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final storeName = expense.storeName?.trim();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Expense details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            if (storeName != null && storeName.isNotEmpty)
              _DetailRow(label: 'Store', value: storeName),
            _DetailRow(label: 'Item', value: expense.item),
            _DetailRow(label: 'Quantity', value: '${expense.quantity}'),
            _DetailRow(label: 'Price', value: _formatMoney(expense.price)),
            _DetailRow(
              label: 'Total',
              value: _formatMoney(expense.total),
              emphasize: true,
            ),
            _DetailRow(
              label: 'Transaction',
              value: _formatTransactionDateTime(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: TextStyle(color: scheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: (emphasize
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.bodyLarge)
                  ?.copyWith(
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: emphasize
                    ? const [FontFeature.tabularFigures()]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
