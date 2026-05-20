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
  }

  String _formatTransactionLabel() {
    return _transactionLabelFormat.format(_transactionAt);
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
      final err = await ref.read(expensesListProvider.notifier).updateExpense(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense updated.')),
      );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final storeName = widget.expense.storeName?.trim();
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.65;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
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
                  const SizedBox(height: 16),
                  if (storeName != null && storeName.isNotEmpty) ...[
                    _ReadOnlyField(label: 'Store', value: storeName),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _itemController,
                    textInputAction: TextInputAction.next,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Item',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter an item name.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _AmountFieldsRow(
                    quantityController: _quantityController,
                    priceController: _priceController,
                    totalController: _totalController,
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 12),
                  _CategoryField(
                    categoriesAsync: categoriesAsync,
                    selectedCategoryId: _selectedCategoryId,
                    currentCategoryName: widget.expense.categoryName,
                    enabled: !_saving,
                    onChanged: (value) =>
                        setState(() => _selectedCategoryId = value),
                  ),
                  const SizedBox(height: 12),
                  _TransactionDateField(
                    label: _formatTransactionLabel(),
                    enabled: !_saving,
                    onTap: _pickTransactionDateTime,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _saving ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          'Close',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountFieldsRow extends StatelessWidget {
  const _AmountFieldsRow({
    required this.quantityController,
    required this.priceController,
    required this.totalController,
    required this.enabled,
  });

  final TextEditingController quantityController;
  final TextEditingController priceController;
  final TextEditingController totalController;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: TextFormField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            enabled: enabled,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _MinQuantityInputFormatter(),
            ],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Qty',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '');
              if (n == null || n < 1) {
                return 'Min 1';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: enabled,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Price',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Required';
              }
              final n = num.tryParse(v.trim());
              if (n == null || n < 0) {
                return 'Invalid';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: totalController,
            readOnly: true,
            enableInteractiveSelection: false,
            decoration: const InputDecoration(
              labelText: 'Total',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({
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

  @override
  Widget build(BuildContext context) {
    return categoriesAsync.when(
      data: (categories) => _CategoryDropdown(
        categories: categories,
        selectedCategoryId: selectedCategoryId,
        enabled: enabled,
        onChanged: onChanged,
      ),
      loading: () => _CategoryDropdown(
        categories: const [],
        selectedCategoryId: selectedCategoryId,
        enabled: false,
        hint: currentCategoryName?.trim().isNotEmpty == true
            ? currentCategoryName!.trim()
            : 'Loading…',
        onChanged: onChanged,
      ),
      error: (Object error, StackTrace stackTrace) => _CategoryDropdown(
        categories: const [],
        selectedCategoryId: selectedCategoryId,
        enabled: enabled,
        helperText: 'Could not load categories.',
        fallbackLabel: currentCategoryName?.trim(),
        onChanged: onChanged,
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.selectedCategoryId,
    required this.enabled,
    required this.onChanged,
    this.hint,
    this.helperText,
    this.fallbackLabel,
  });

  final List<ExpenseCategory> categories;
  final int? selectedCategoryId;
  final bool enabled;
  final ValueChanged<int?> onChanged;
  final String? hint;
  final String? helperText;
  final String? fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final labelsById = <int, String>{};
    for (final category in categories) {
      labelsById.putIfAbsent(category.id, () => category.name);
    }

    if (selectedCategoryId != null && !labelsById.containsKey(selectedCategoryId)) {
      final orphanLabel = fallbackLabel?.trim();
      if (orphanLabel != null && orphanLabel.isNotEmpty) {
        labelsById[selectedCategoryId!] = orphanLabel;
      }
    }

    final sortedEntries = labelsById.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('None')),
      for (final entry in sortedEntries)
        DropdownMenuItem<int?>(
          value: entry.key,
          child: Text(entry.value),
        ),
    ];

    final dropdownValue = selectedCategoryId != null &&
            labelsById.containsKey(selectedCategoryId)
        ? selectedCategoryId
        : null;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Category',
        border: const OutlineInputBorder(),
        helperText: helperText,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: dropdownValue,
          isExpanded: true,
          hint: Text(hint ?? 'None'),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _TransactionDateField extends StatelessWidget {
  const _TransactionDateField({
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

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Transaction',
          border: const OutlineInputBorder(),
          suffixIcon: Icon(
            Icons.calendar_today_outlined,
            color: enabled ? scheme.onSurfaceVariant : scheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabled: false,
      ),
      child: Text(
        value,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
