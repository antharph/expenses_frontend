import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../dashboard/application/dashboard_expense_summary_provider.dart';
import '../application/categories_provider.dart';
import '../application/expenses_list_notifier.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import 'add_expense_sheet.dart';
import 'expense_detail_sheet.dart';

final _amountFormat = NumberFormat.currency(
  symbol: r'',
  decimalDigits: 2,
);

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

  Future<void> _showDateRangeSheet({
    required DateTime? rangeStart,
    required DateTime? rangeEnd,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _DateRangeFilterSheet(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        onApply: (start, end) {
          ref.read(expensesListProvider.notifier).setDateRange(
                start: start,
                end: end,
              );
        },
        onClear: () {
          ref.read(expensesListProvider.notifier).clearDateRange();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(expensesListProvider);
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final filtered = list.filteredItems;
    final groupedEntries = _groupExpenses(filtered);
    final itemCount = groupedEntries.length + (list.isLoadingMore ? 1 : 0);
    final selectedCategoryName = _categoryName(
      categoriesAsync.valueOrNull,
      list.categoryId,
    );
    final showHero =
        list.isLoadingInitial ||
        filtered.isNotEmpty ||
        (list.hasAggregateSummary &&
            (list.hasDateFilter ||
                list.hasCategoryFilter ||
                (list.aggregateTotalCount ?? 0) > 0));

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
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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
          if (showHero)
            _ExpensesHeroHeader(
              hasDateFilter: list.hasDateFilter,
              rangeStart: list.dateRangeStart,
              rangeEnd: list.dateRangeEnd,
              categoryLabel: selectedCategoryName,
              isLoading: list.isLoadingInitial && !list.hasAggregateSummary,
              totalCount: list.aggregateTotalCount,
              sumTotal: list.aggregateSumTotal,
              loadedCount: filtered.length,
            ),
          _ExpensesFilterPanel(
            hasDateFilter: list.hasDateFilter,
            rangeStart: list.dateRangeStart,
            rangeEnd: list.dateRangeEnd,
            categoriesAsync: categoriesAsync,
            selectedCategoryId: list.categoryId,
            onDateRangeTap: () => _showDateRangeSheet(
              rangeStart: list.dateRangeStart,
              rangeEnd: list.dateRangeEnd,
            ),
            onCategorySelected: (categoryId) => ref
                .read(expensesListProvider.notifier)
                .setCategoryFilter(categoryId),
          ),
          Expanded(
            child: list.isLoadingInitial && list.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : list.items.isEmpty && list.initialError != null
                ? _ExpensesErrorState(
                    message: list.initialError!,
                    onRetry: () =>
                        ref.read(expensesListProvider.notifier).loadInitial(),
                  )
                : filtered.isEmpty
                ? _ExpensesEmptyState(
                    filtered: list.hasDateFilter || list.hasCategoryFilter,
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(expensesListProvider.notifier).refresh(),
                    child: SlidableAutoCloseBehavior(
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          0,
                          0,
                          0,
                          MediaQuery.paddingOf(context).bottom + 112,
                        ),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index >= groupedEntries.length) {
                            return const _LoadingMoreFooter();
                          }

                          final entry = groupedEntries[index];
                          return switch (entry) {
                            _ExpenseSectionHeader(:final label) =>
                              _ExpenseDateSectionHeader(label: label),
                            _ExpenseListItem(:final expense) => _ExpenseListTile(
                                expense: expense,
                                showCategory: !list.hasCategoryFilter,
                              ),
                          };
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String? _categoryName(List<ExpenseCategory>? categories, int? categoryId) {
    if (categoryId == null || categories == null) {
      return null;
    }
    for (final category in categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Grouped list model — dates live in section headers, not on every row.
// ---------------------------------------------------------------------------

sealed class _ExpenseListEntry {}

class _ExpenseSectionHeader extends _ExpenseListEntry {
  _ExpenseSectionHeader(this.label);

  final String label;
}

class _ExpenseListItem extends _ExpenseListEntry {
  _ExpenseListItem(this.expense);

  final Expense expense;
}

List<_ExpenseListEntry> _groupExpenses(List<Expense> items) {
  if (items.isEmpty) {
    return const [];
  }

  final buckets = <DateTime, List<Expense>>{};
  final order = <DateTime>[];

  for (final expense in items) {
    final iso = expense.transactionAtIso ?? expense.dateIso;
    final parsed = DateTime.tryParse(iso)?.toLocal();
    final day = parsed != null
        ? DateTime(parsed.year, parsed.month, parsed.day)
        : DateTime.fromMillisecondsSinceEpoch(0);

    if (!buckets.containsKey(day)) {
      buckets[day] = [];
      order.add(day);
    }
    buckets[day]!.add(expense);
  }

  final entries = <_ExpenseListEntry>[];
  for (final day in order) {
    entries.add(_ExpenseSectionHeader(_sectionLabel(day)));
    for (final expense in buckets[day]!) {
      entries.add(_ExpenseListItem(expense));
    }
  }
  return entries;
}

String _sectionLabel(DateTime day) {
  if (day.millisecondsSinceEpoch == 0) {
    return 'Unknown date';
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) {
    return 'Today';
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  if (day.isAfter(today.subtract(const Duration(days: 7)))) {
    return DateFormat('EEEE').format(day);
  }
  return DateFormat.yMMMd().format(day);
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

// ---------------------------------------------------------------------------
// Hero metric — primary scan target for the screen.
// ---------------------------------------------------------------------------

class _ExpensesHeroHeader extends StatelessWidget {
  const _ExpensesHeroHeader({
    required this.hasDateFilter,
    required this.rangeStart,
    required this.rangeEnd,
    this.categoryLabel,
    required this.isLoading,
    required this.totalCount,
    required this.sumTotal,
    required this.loadedCount,
  });

  final bool hasDateFilter;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final String? categoryLabel;
  final bool isLoading;
  final int? totalCount;
  final double? sumTotal;
  final int loadedCount;

  static final _rangeFormat = DateFormat.yMMMd();

  String _contextLabel() {
    final parts = <String>[];
    if (hasDateFilter && rangeStart != null && rangeEnd != null) {
      parts.add(
        '${_rangeFormat.format(rangeStart!)} – ${_rangeFormat.format(rangeEnd!)}',
      );
    }
    if (categoryLabel != null) {
      parts.add(_displayLabel(categoryLabel!));
    }
    if (parts.isEmpty) {
      return 'All expenses';
    }
    return parts.join(' · ');
  }

  String _countLabel(int count) {
    return count == 1 ? '1 expense' : '$count expenses';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: isLoading
          ? const SizedBox(
              height: 88,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _contextLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                if (sumTotal != null)
                  Text(
                    _amountFormat.format(sumTotal),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                const SizedBox(height: 4),
                if (totalCount != null)
                  Text(
                    _countLabel(totalCount!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (totalCount != null &&
                    loadedCount < totalCount! &&
                    totalCount! > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Showing $loadedCount of ${totalCount!}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Unified filter strip — date pill + category chips in one surface.
// ---------------------------------------------------------------------------

class _ExpensesFilterPanel extends StatelessWidget {
  const _ExpensesFilterPanel({
    required this.hasDateFilter,
    required this.rangeStart,
    required this.rangeEnd,
    required this.categoriesAsync,
    required this.selectedCategoryId,
    required this.onDateRangeTap,
    required this.onCategorySelected,
  });

  final bool hasDateFilter;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final AsyncValue<List<ExpenseCategory>> categoriesAsync;
  final int? selectedCategoryId;
  final VoidCallback onDateRangeTap;
  final ValueChanged<int?> onCategorySelected;

  static final _displayFormat = DateFormat.yMMMd();

  String _datePillLabel() {
    if (hasDateFilter && rangeStart != null && rangeEnd != null) {
      return '${_displayFormat.format(rangeStart!)} – ${_displayFormat.format(rangeEnd!)}';
    }
    return 'All dates';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: 'Date range, ${_datePillLabel()}',
            child: Material(
              color: hasDateFilter
                  ? scheme.primaryContainer.withValues(alpha: 0.35)
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onDateRangeTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _datePillLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: hasDateFilter
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) {
                return const SizedBox.shrink();
              }

              final sorted = List<ExpenseCategory>.from(categories)
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );

              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CategoryChip(
                        label: 'All',
                        selected: selectedCategoryId == null,
                        accent: scheme.outline,
                        onTap: selectedCategoryId == null
                            ? null
                            : () => onCategorySelected(null),
                      ),
                      for (final category in sorted) ...[
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: category.name,
                          selected: selectedCategoryId == category.id,
                          accent: _categoryAccent(scheme, category.name),
                          onTap: () => onCategorySelected(category.id),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 10),
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _displayLabel(label),
                  style: theme.textTheme.labelLarge?.copyWith(
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
      ),
    );
  }
}

class _DateRangeFilterSheet extends StatefulWidget {
  const _DateRangeFilterSheet({
    required this.rangeStart,
    required this.rangeEnd,
    required this.onApply,
    required this.onClear,
  });

  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final void Function(DateTime? start, DateTime? end) onApply;
  final VoidCallback onClear;

  @override
  State<_DateRangeFilterSheet> createState() => _DateRangeFilterSheetState();
}

class _DateRangeFilterSheetState extends State<_DateRangeFilterSheet> {
  late DateTime? _start;
  late DateTime? _end;

  static final _displayFormat = DateFormat.yMMMd();

  @override
  void initState() {
    super.initState();
    _start = widget.rangeStart;
    _end = widget.rangeEnd;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = isStart ? _start : _end;
    final other = isStart ? _end : _start;
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

    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _apply() {
    widget.onApply(_start, _end);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasRange = _start != null && _end != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Date range',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _DateSheetTile(
            label: 'From',
            value: _start != null ? _displayFormat.format(_start!) : null,
            onTap: () => _pickDate(isStart: true),
          ),
          const SizedBox(height: 8),
          _DateSheetTile(
            label: 'To',
            value: _end != null ? _displayFormat.format(_end!) : null,
            onTap: () => _pickDate(isStart: false),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (hasRange)
                TextButton(
                  onPressed: () {
                    widget.onClear();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Clear'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: hasRange ? _apply : null,
                child: const Text('Apply'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Select both dates to filter the list.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSheetTile extends StatelessWidget {
  const _DateSheetTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
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
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value ?? 'Select date',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            value != null ? FontWeight.w500 : FontWeight.w400,
                        color: value != null
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.calendar_today_outlined, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List — section headers + minimal divider rows.
// ---------------------------------------------------------------------------

class _ExpenseDateSectionHeader extends StatelessWidget {
  const _ExpenseDateSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ExpenseListTile extends ConsumerWidget {
  const _ExpenseListTile({
    required this.expense,
    required this.showCategory,
  });

  final Expense expense;
  final bool showCategory;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense'),
        content: Text(
          'Remove "${_displayLabel(expense.item)}"? This cannot be undone.',
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
    final category = expenseCategoryLabel(expense);
    final amountStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final row = Material(
      color: scheme.surface,
      child: InkWell(
        onTap: () => showExpenseDetailSheet(context, expense),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayLabel(expense.item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (showCategory) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _categoryAccent(scheme, category),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _displayLabel(category),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                expense.total,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: amountStyle,
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      children: [
        Slidable(
          key: ValueKey<int>(expense.id),
          groupTag: 'expenses_list',
          endActionPane: ActionPane(
            extentRatio: 0.22,
            motion: const BehindMotion(),
            dragDismissible: false,
            children: [
              CustomSlidableAction(
                onPressed: (_) => _confirmDelete(context, ref),
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                padding: EdgeInsets.zero,
                child: Icon(Icons.delete_outline, color: scheme.onError),
              ),
            ],
          ),
          child: row,
        ),
        Divider(
          height: 1,
          thickness: 1,
          indent: 20,
          endIndent: 20,
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ],
    );
  }
}

class _LoadingMoreFooter extends StatelessWidget {
  const _LoadingMoreFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class _ExpensesEmptyState extends StatelessWidget {
  const _ExpensesEmptyState({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtered ? Icons.filter_list_off_outlined : Icons.receipt_long_outlined,
              size: 48,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              filtered ? 'No matching expenses' : 'No expenses yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              filtered
                  ? 'Try adjusting your date range or category filter.'
                  : 'Tap Add expense to record your first one.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpensesErrorState extends StatelessWidget {
  const _ExpensesErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
