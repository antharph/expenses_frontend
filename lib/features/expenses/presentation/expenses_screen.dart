import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../dashboard/application/dashboard_expense_summary_provider.dart';
import '../../dashboard/presentation/sign_out_menu_button.dart';
import '../application/expenses_list_notifier.dart';
import '../domain/expense.dart';
import 'add_expense_sheet.dart';
import 'expense_detail_sheet.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(expensesListProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      ref.read(expensesListProvider.notifier).loadMore();
    }
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) {
      return '—';
    }
    final dt = DateTime.tryParse(iso);
    if (dt == null) {
      return iso;
    }
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate({
    required bool isStart,
    required DateTime? current,
    required DateTime? other,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = current ?? other ?? today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked == null || !mounted) {
      return;
    }

    final notifier = ref.read(expensesListProvider.notifier);
    if (isStart) {
      notifier.setDateRange(start: picked, end: other);
    } else {
      notifier.setDateRange(start: other, end: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(expensesListProvider);
    final filtered = list.filteredItems;
    final itemCount = filtered.length + (list.isLoadingMore ? 1 : 0);
    final showSummaryBar =
        list.isLoadingInitial ||
        filtered.isNotEmpty ||
        (list.hasAggregateSummary &&
            (list.hasDateFilter || (list.aggregateTotalCount ?? 0) > 0));

    ref.listen<ExpensesListState>(expensesListProvider, (previous, next) {
      final msg = next.initialError;
      if (msg != null && msg.isNotEmpty && msg != previous?.initialError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: const [SignOutMenuButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (context) => const AddExpenseSheet(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DateRangeFilterBar(
            rangeStart: list.dateRangeStart,
            rangeEnd: list.dateRangeEnd,
            onPickStart: () => _pickDate(
              isStart: true,
              current: list.dateRangeStart,
              other: list.dateRangeEnd,
            ),
            onPickEnd: () => _pickDate(
              isStart: false,
              current: list.dateRangeEnd,
              other: list.dateRangeStart,
            ),
            onClear: list.hasDateFilter
                ? () => ref.read(expensesListProvider.notifier).clearDateRange()
                : null,
          ),
          if (showSummaryBar)
            _ExpensesSummaryBar(
              hasDateFilter: list.hasDateFilter,
              rangeStart: list.dateRangeStart,
              rangeEnd: list.dateRangeEnd,
              isLoading: list.isLoadingInitial && !list.hasAggregateSummary,
              totalCount: list.aggregateTotalCount,
              sumTotal: list.aggregateSumTotal,
              loadedCount: filtered.length,
            ),
          Expanded(
            child: list.isLoadingInitial && list.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : list.items.isEmpty && list.initialError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(list.initialError!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => ref
                                .read(expensesListProvider.notifier)
                                .loadInitial(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        list.hasDateFilter
                            ? 'No expenses in this date range.'
                            : 'No expenses yet.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(expensesListProvider.notifier).refresh(),
                    child: SlidableAutoCloseBehavior(
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          MediaQuery.paddingOf(context).bottom + 112,
                        ),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index < filtered.length) {
                            return _ExpenseRow(
                              expense: filtered[index],
                              formatDate: _formatDate,
                            );
                          }

                          return const _LoadingMoreFooter();
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DateRangeFilterBar extends StatelessWidget {
  const _DateRangeFilterBar({
    required this.rangeStart,
    required this.rangeEnd,
    required this.onPickStart,
    required this.onPickEnd,
    this.onClear,
  });

  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback? onClear;

  static final _displayFormat = DateFormat.yMMMd();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: _DateField(
                label: 'From',
                value: rangeStart != null
                    ? _displayFormat.format(rangeStart!)
                    : 'Select date',
                onTap: onPickStart,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: _DateField(
                label: 'To',
                value: rangeEnd != null
                    ? _displayFormat.format(rangeEnd!)
                    : 'Select date',
                onTap: onPickEnd,
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                tooltip: 'Clear date filter',
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: '$label, $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(Icons.calendar_today, size: 18, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpensesSummaryBar extends StatelessWidget {
  const _ExpensesSummaryBar({
    required this.hasDateFilter,
    required this.rangeStart,
    required this.rangeEnd,
    required this.isLoading,
    required this.totalCount,
    required this.sumTotal,
    required this.loadedCount,
  });

  final bool hasDateFilter;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final bool isLoading;
  final int? totalCount;
  final double? sumTotal;
  final int loadedCount;

  static final _rangeFormat = DateFormat.yMMMd();
  static final _amountFormat = NumberFormat.currency(
    symbol: r'',
    decimalDigits: 2,
  );

  String _scopeLabel() {
    if (hasDateFilter && rangeStart != null && rangeEnd != null) {
      return '${_rangeFormat.format(rangeStart!)} – ${_rangeFormat.format(rangeEnd!)}';
    }
    return 'All expenses';
  }

  String _countLabel(int count) {
    return count == 1 ? '1 expense' : '$count expenses';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: isLoading
            ? const SizedBox(
                height: 52,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _scopeLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (totalCount != null)
                        Text(
                          _countLabel(totalCount!),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      const Spacer(),
                      if (sumTotal != null)
                        Text(
                          _amountFormat.format(sumTotal),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                  if (totalCount != null &&
                      loadedCount < totalCount! &&
                      totalCount! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Showing $loadedCount of ${totalCount!}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _LoadingMoreFooter extends StatelessWidget {
  const _LoadingMoreFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({required this.expense, required this.formatDate});

  final Expense expense;
  final String Function(String iso) formatDate;

  static const double _cardRadius = 12;
  static const double _dateColumnWidth = 88;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense'),
        content: Text('Remove "${expense.item}"? This cannot be undone.'),
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
    if (confirmed != true || !context.mounted) {
      return;
    }

    final err = await ref
        .read(expensesListProvider.notifier)
        .deleteExpense(expense.id);
    if (!context.mounted) {
      return;
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ref.invalidate(dashboardExpenseSummaryProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cardColor = theme.brightness == Brightness.light
        ? const Color(0xFFF9FAFB)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.55);

    final amountStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final row = Material(
      color: cardColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showExpenseDetailSheet(context, expense),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _dateColumnWidth,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    formatDate(expense.transactionAtIso ?? expense.dateIso),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expenseCategoryLabel(expense),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  expense.total,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: amountStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_cardRadius),
        clipBehavior: Clip.hardEdge,
        child: Slidable(
          key: ValueKey<int>(expense.id),
          groupTag: 'expenses_list',
          endActionPane: ActionPane(
            extentRatio: 0.28,
            motion: const BehindMotion(),
            dragDismissible: false,
            children: [
              CustomSlidableAction(
                onPressed: (_) => _confirmDelete(context, ref),
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline, color: scheme.onError, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      'Delete',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onError,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          child: row,
        ),
      ),
    );
  }
}
