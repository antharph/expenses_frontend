import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/application/session_notifier.dart';
import '../../dashboard/application/dashboard_expense_summary_provider.dart';
import '../application/categories_provider.dart';
import '../application/expenses_list_notifier.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import '../domain/expense_date.dart';

void showExpenseDetailSheet(BuildContext context, Expense expense) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => ExpenseDetailSheet(expense: expense),
  );
}

class _MinQuantityInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '1',
        selection: TextSelection.collapsed(offset: 1),
      );
    }

    final parsed = int.tryParse(newValue.text);
    if (parsed != null && parsed < 1) {
      return const TextEditingValue(
        text: '1',
        selection: TextSelection.collapsed(offset: 1),
      );
    }

    return newValue;
  }
}

class ExpenseDetailSheet extends ConsumerStatefulWidget {
  const ExpenseDetailSheet({super.key, required this.expense});

  final Expense expense;

  @override
  ConsumerState<ExpenseDetailSheet> createState() => _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends ConsumerState<ExpenseDetailSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _itemController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _totalController;
  late DateTime _transactionAt;
  late int? _selectedCategoryId;

  static final _transactionLabelFormat = DateFormat.yMMMd().add_jm();
  static final _heroTotalFormat = NumberFormat.currency(
    symbol: r'',
    decimalDigits: 2,
  );

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _itemController = TextEditingController(text: expense.item);
    _quantityController = TextEditingController(text: '${expense.quantity}');
    _priceController = TextEditingController(text: expense.price);
    _totalController = TextEditingController(text: expense.total);
    _transactionAt = _initialTransactionAt(expense);
    _selectedCategoryId = expense.categoryId;
    _priceController.addListener(_syncTotal);
    _quantityController.addListener(_syncTotal);
  }

  DateTime _initialTransactionAt(Expense expense) {
    final raw = expense.transactionAtIso ?? expense.dateIso;
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return parsed.toLocal();
    }

    final day = expenseLocalDay(raw);
    if (day != null) {
      return day;
    }

    return DateTime.now();
  }

  @override
  void dispose() {
    _priceController.removeListener(_syncTotal);
    _quantityController.removeListener(_syncTotal);
    _itemController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _syncTotal() {
    final price = num.tryParse(_priceController.text.trim()) ?? 0;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    final formatted = (price * quantity).toStringAsFixed(2);
    if (_totalController.text == formatted) {
      return;
    }
    _totalController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {});
  }

  String _formatTransactionLabel() {
    return _transactionLabelFormat.format(_transactionAt);
  }

  String _heroTotalLabel() {
    final parsed = num.tryParse(_totalController.text.trim());
    if (parsed == null) {
      return _totalController.text.trim();
    }
    return _heroTotalFormat.format(parsed);
  }

  String _apiDate(DateTime local) {
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _apiTime(DateTime local) {
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  Future<void> _pickTransactionDateTime() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _transactionAt,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_transactionAt),
    );
    if (!mounted) {
      return;
    }

    final time = pickedTime ?? TimeOfDay.fromDateTime(_transactionAt);
    setState(() {
      _transactionAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedCategoryId == null) {
      setState(() => _error = 'Select a category.');
      return;
    }

    final token = ref.read(sessionProvider).valueOrNull?.token;
    if (token == null) {
      setState(() => _error = 'Not signed in.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
      final err = await ref
          .read(expensesListProvider.notifier)
          .updateExpense(
            id: widget.expense.id,
            item: _itemController.text.trim(),
            quantity: quantity,
            price: _priceController.text.trim(),
            transactionDate: _apiDate(_transactionAt),
            transactionTime: _apiTime(_transactionAt),
            categoryId: _selectedCategoryId,
          );
      ref.invalidate(dashboardExpenseSummaryProvider);
      if (!mounted) {
        return;
      }
      if (err != null) {
        setState(() {
          _saving = false;
          _error = err;
        });
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Expense updated.')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    Color? fillColor,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: fillColor ?? scheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final storeName = widget.expense.storeName?.trim();
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottomInset + safeBottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Expense details',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (storeName != null && storeName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _displayLabel(storeName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Total',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _heroTotalLabel(),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.05,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 20),
            _ExpenseDetailsSection(
              saving: _saving,
              itemController: _itemController,
              quantityController: _quantityController,
              priceController: _priceController,
              fieldDecoration: _fieldDecoration,
            ),
            const SizedBox(height: 16),
            _ExpenseCategoryField(
              categoriesAsync: categoriesAsync,
              selectedCategoryId: _selectedCategoryId,
              currentCategoryName: widget.expense.categoryName,
              enabled: !_saving,
              onChanged: (value) => setState(() {
                _selectedCategoryId = value;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            _TransactionPicker(
              label: _formatTransactionLabel(),
              enabled: !_saving,
              onTap: _pickTransactionDateTime,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _FormErrorBanner(message: _error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save changes',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseDetailsSection extends StatelessWidget {
  const _ExpenseDetailsSection({
    required this.saving,
    required this.itemController,
    required this.quantityController,
    required this.priceController,
    required this.fieldDecoration,
  });

  final bool saving;
  final TextEditingController itemController;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final InputDecoration Function(
    BuildContext, {
    required String label,
    Color? fillColor,
  })
  fieldDecoration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: itemController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              enabled: !saving,
              decoration: fieldDecoration(context, label: 'Item'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter an item name.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    enabled: !saving,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _MinQuantityInputFormatter(),
                    ],
                    textInputAction: TextInputAction.next,
                    decoration: fieldDecoration(context, label: 'Qty'),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 1) {
                        return 'Min 1.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    enabled: !saving,
                    textInputAction: TextInputAction.done,
                    decoration: fieldDecoration(context, label: 'Unit price'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Required.';
                      }
                      final n = num.tryParse(v.trim());
                      if (n == null || n < 0) {
                        return 'Invalid.';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseCategoryField extends StatelessWidget {
  const _ExpenseCategoryField({
    required this.categoriesAsync,
    required this.selectedCategoryId,
    required this.currentCategoryName,
    required this.enabled,
    required this.onChanged,
  });

  final AsyncValue<List<ExpenseCategory>> categoriesAsync;
  final int? selectedCategoryId;
  final String? currentCategoryName;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  List<ExpenseCategory> _orderedCategories(List<ExpenseCategory> categories) {
    final sorted = List<ExpenseCategory>.from(categories)
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    if (selectedCategoryId == null) {
      return sorted;
    }

    final selectedIndex = sorted.indexWhere(
      (category) => category.id == selectedCategoryId,
    );
    if (selectedIndex <= 0) {
      return sorted;
    }

    final selected = sorted.removeAt(selectedIndex);
    return [selected, ...sorted];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              final fallback = currentCategoryName?.trim();
              if (fallback != null && fallback.isNotEmpty) {
                return Text(
                  _displayLabel(fallback),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                );
              }
              return Text(
                'No categories available.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              );
            }

            final labelsById = {
              for (final category in categories) category.id: category.name,
            };
            if (selectedCategoryId != null &&
                !labelsById.containsKey(selectedCategoryId)) {
              final orphanLabel = currentCategoryName?.trim();
              if (orphanLabel != null && orphanLabel.isNotEmpty) {
                labelsById[selectedCategoryId!] = orphanLabel;
              }
            }

            final ordered = _orderedCategories(
              labelsById.entries
                  .map(
                    (entry) => ExpenseCategory(
                      id: entry.key,
                      name: entry.value,
                    ),
                  )
                  .toList(),
            );

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in ordered)
                  _CategoryChoiceChip(
                    label: category.name,
                    selected: selectedCategoryId == category.id,
                    accent: _categoryAccent(scheme, category.name),
                    enabled: enabled,
                    onTap: () => onChanged(category.id),
                  ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 48,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
          error: (_, _) {
            final fallback = currentCategoryName?.trim();
            return Text(
              fallback != null && fallback.isNotEmpty
                  ? _displayLabel(fallback)
                  : 'Could not load categories.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: fallback != null && fallback.isNotEmpty
                    ? scheme.onSurfaceVariant
                    : scheme.error,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CategoryChoiceChip extends StatelessWidget {
  const _CategoryChoiceChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

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
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

class _TransactionPicker extends StatelessWidget {
  const _TransactionPicker({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: enabled
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface.withValues(alpha: 0.38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormErrorBanner extends StatelessWidget {
  const _FormErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.errorContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 20, color: scheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
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
