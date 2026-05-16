import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../application/expenses_list_notifier.dart';
import '../domain/expense.dart';
import 'add_expense_sheet.dart';

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

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(expensesListProvider);

    ref.listen<ExpensesListState>(expensesListProvider, (previous, next) {
      final msg = next.initialError;
      if (msg != null && msg.isNotEmpty && msg != previous?.initialError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
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
      body: list.isLoadingInitial && list.items.isEmpty
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
                          onPressed: () => ref.read(expensesListProvider.notifier).loadInitial(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(expensesListProvider.notifier).refresh(),
                  child: SlidableAutoCloseBehavior(
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: list.items.length + (list.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= list.items.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: list.isLoadingMore
                                  ? const CircularProgressIndicator()
                                  : const SizedBox.shrink(),
                            ),
                          );
                        }
                        return _ExpenseRow(
                          expense: list.items[index],
                          formatDate: _formatDate,
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({required this.expense, required this.formatDate});

  final Expense expense;
  final String Function(String iso) formatDate;

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

    final err = await ref.read(expensesListProvider.notifier).deleteExpense(expense.id);
    if (!context.mounted) {
      return;
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                formatDate(expense.dateIso),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                expense.item,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                expense.price,
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey<int>(expense.id),
        groupTag: 'expenses_list',
        endActionPane: ActionPane(
          extentRatio: 0.26,
          motion: const BehindMotion(),
          dragDismissible: false,
          children: [
            SlidableAction(
              onPressed: (_) => _confirmDelete(context, ref),
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              icon: Icons.delete_outline,
              label: 'Delete',
              flex: 1,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        child: card,
      ),
    );
  }
}
