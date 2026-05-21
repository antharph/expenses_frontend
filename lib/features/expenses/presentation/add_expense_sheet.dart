import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/api_errors.dart';
import '../../auth/application/session_notifier.dart';
import '../../dashboard/application/dashboard_expense_summary_provider.dart';
import '../application/categories_provider.dart';
import '../application/expenses_list_notifier.dart';
import '../data/expenses_api.dart';
import '../domain/expense_category.dart';

enum _ExpenseEntryMode { receipt, manual }

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

class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({super.key});

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  static const double _receiptMaxWidth = 1200;
  static const int _receiptImageQuality = 82;

  final _formKey = GlobalKey<FormState>();
  final _itemController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _totalController = TextEditingController(text: '0.00');
  _ExpenseEntryMode _entryMode = _ExpenseEntryMode.receipt;
  XFile? _receipt;
  int? _selectedCategoryId;
  bool _categoryTouched = false;
  bool _pickingReceipt = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_syncTotal);
    _quantityController.addListener(_syncTotal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categories = ref.read(expenseCategoriesProvider).valueOrNull;
      if (categories != null) {
        _ensureDefaultCategory(categories);
      }
    });
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

  void _ensureDefaultCategory(List<ExpenseCategory> categories) {
    if (_selectedCategoryId != null) {
      return;
    }
    final defaultId = defaultExpenseCategoryId(categories);
    if (defaultId != null && mounted) {
      setState(() => _selectedCategoryId = defaultId);
    }
  }

  String _filenameFromPath(String path) {
    final i = path.lastIndexOf(RegExp(r'[/\\]'));
    return i >= 0 ? path.substring(i + 1) : path;
  }

  Future<void> _pickImage() async {
    setState(() {
      _pickingReceipt = true;
      _error = null;
    });

    final picker = ImagePicker();
    try {
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _receiptMaxWidth,
        imageQuality: _receiptImageQuality,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _receipt = x;
        _pickingReceipt = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pickingReceipt = false;
        _error = 'Could not prepare the receipt image.';
      });
    }
  }

  void _removeReceipt() {
    setState(() {
      _receipt = null;
      _error = null;
    });
  }

  void _setEntryMode(_ExpenseEntryMode mode) {
    if (mode == _entryMode || _saving) {
      return;
    }
    setState(() {
      _entryMode = mode;
      _error = null;
      if (mode == _ExpenseEntryMode.manual) {
        _receipt = null;
      } else {
        _itemController.clear();
        _quantityController.text = '1';
        _priceController.clear();
        _totalController.text = '0.00';
      }
    });
  }

  bool _hasCategory([List<ExpenseCategory>? categories]) {
    return _resolvedCategoryId(categories) != null;
  }

  int? _resolvedCategoryId(List<ExpenseCategory>? categories) {
    if (_selectedCategoryId != null) {
      return _selectedCategoryId;
    }
    if (categories == null) {
      return null;
    }
    return defaultExpenseCategoryId(categories);
  }

  bool _canSave() {
    final categories = ref.read(expenseCategoriesProvider).valueOrNull;
    if (_saving || !_hasCategory(categories)) {
      return false;
    }
    if (_entryMode == _ExpenseEntryMode.receipt) {
      return _receipt != null;
    }
    return true;
  }

  Future<void> _save() async {
    final categories = ref.read(expenseCategoriesProvider).valueOrNull;
    final categoryId = _resolvedCategoryId(categories);
    if (categoryId == null) {
      setState(() {
        _categoryTouched = true;
        _error = 'Select a category.';
      });
      return;
    }

    _selectedCategoryId ??= categoryId;

    if (_entryMode == _ExpenseEntryMode.receipt) {
      if (_receipt == null) {
        setState(() => _error = 'Select a receipt image to continue.');
        return;
      }
    } else if (!_formKey.currentState!.validate()) {
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
      final api = ref.read(expensesApiProvider);
      final receipt = _receipt;
      final isReceiptMode = _entryMode == _ExpenseEntryMode.receipt;
      final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
      await api.createExpense(
        token: token,
        item: isReceiptMode ? null : _itemController.text.trim(),
        quantity: isReceiptMode ? null : quantity,
        price: isReceiptMode ? null : _priceController.text.trim(),
        receiptFilePath: isReceiptMode ? receipt?.path : null,
        receiptFilename: isReceiptMode && receipt != null
            ? _filenameFromPath(receipt.path)
            : null,
        categoryId: categoryId,
      );
      await ref.read(expensesListProvider.notifier).refresh();
      ref.invalidate(dashboardExpenseSummaryProvider);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Expense saved.')));
    } on DioException catch (e) {
      setState(() {
        _saving = false;
        _error = formatApiError(e);
      });
    } catch (e) {
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    final categories = categoriesAsync.valueOrNull;
    final resolvedCategoryId = _resolvedCategoryId(categories);

    ref.listen<AsyncValue<List<ExpenseCategory>>>(expenseCategoriesProvider, (
      _,
      next,
    ) {
      next.whenData(_ensureDefaultCategory);
    });

    final showCategoryError =
        _categoryTouched && resolvedCategoryId == null && !categoriesAsync.isLoading;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottomInset + safeBottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New expense',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _entryMode == _ExpenseEntryMode.receipt
                  ? 'Upload a receipt or enter details manually.'
                  : 'Enter item details below.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<_ExpenseEntryMode>(
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(
                  value: _ExpenseEntryMode.receipt,
                  label: Text('Receipt'),
                  icon: Icon(Icons.receipt_long_outlined, size: 18),
                ),
                ButtonSegment(
                  value: _ExpenseEntryMode.manual,
                  label: Text('Manual'),
                  icon: Icon(Icons.edit_outlined, size: 18),
                ),
              ],
              selected: {_entryMode},
              onSelectionChanged: _saving
                  ? null
                  : (selection) => _setEntryMode(selection.first),
            ),
            const SizedBox(height: 20),
            _AddExpenseCategoryField(
              categoriesAsync: categoriesAsync,
              selectedCategoryId: resolvedCategoryId,
              enabled: !_saving,
              showError: showCategoryError,
              onChanged: (categoryId) => setState(() {
                _selectedCategoryId = categoryId;
                _categoryTouched = true;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            if (_entryMode == _ExpenseEntryMode.receipt) ...[
              if (_receipt == null)
                _ReceiptUploadSection(
                  picking: _pickingReceipt,
                  saving: _saving,
                  onPick: _pickImage,
                )
              else ...[
                _ReceiptPreview(
                  file: File(_receipt!.path),
                  filename: _filenameFromPath(_receipt!.path),
                  onRemove: _saving ? null : _removeReceipt,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _saving || _pickingReceipt ? null : _pickImage,
                    icon: _pickingReceipt
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.swap_horiz, size: 18),
                    label: Text(
                      _pickingReceipt ? 'Preparing…' : 'Change receipt',
                    ),
                  ),
                ),
              ],
            ] else
              _ManualEntryFields(
                itemController: _itemController,
                quantityController: _quantityController,
                priceController: _priceController,
                totalController: _totalController,
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _FormErrorBanner(message: _error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canSave() ? _save : null,
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
                      _entryMode == _ExpenseEntryMode.receipt
                          ? 'Save from receipt'
                          : 'Save expense',
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

class _AddExpenseCategoryField extends StatelessWidget {
  const _AddExpenseCategoryField({
    required this.categoriesAsync,
    required this.selectedCategoryId,
    required this.enabled,
    required this.showError,
    required this.onChanged,
  });

  final AsyncValue<List<ExpenseCategory>> categoriesAsync;
  final int? selectedCategoryId;
  final bool enabled;
  final bool showError;
  final ValueChanged<int?> onChanged;

  List<ExpenseCategory> _orderedCategories(List<ExpenseCategory> categories) {
    final sorted = List<ExpenseCategory>.from(categories)
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    if (selectedCategoryId == null) {
      return sorted;
    }

    final selected = sorted
        .where((category) => category.id == selectedCategoryId)
        .toList();
    final rest = sorted
        .where((category) => category.id != selectedCategoryId)
        .toList();
    return [...selected, ...rest];
  }

  ExpenseCategory? _selectedCategory(List<ExpenseCategory> categories) {
    if (selectedCategoryId == null) {
      return null;
    }
    for (final category in categories) {
      if (category.id == selectedCategoryId) {
        return category;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Category',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ' *',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              return Text(
                'No categories available.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              );
            }

            final ordered = _orderedCategories(categories);
            final selected = _selectedCategory(categories);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (selected != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _categoryAccent(scheme, selected.name),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _displayLabel(selected.name),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < ordered.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _CategoryChoiceChip(
                          label: ordered[i].name,
                          selected: selectedCategoryId == ordered[i].id,
                          accent: _categoryAccent(scheme, ordered[i].name),
                          enabled: enabled,
                          onTap: () => onChanged(ordered[i].id),
                        ),
                      ],
                    ],
                  ),
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
          error: (_, _) => Text(
            'Could not load categories.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Select a category.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
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

class _ReceiptUploadSection extends StatelessWidget {
  const _ReceiptUploadSection({
    required this.picking,
    required this.saving,
    required this.onPick,
  });

  final bool picking;
  final bool saving;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final enabled = !picking && !saving;

    return Semantics(
      button: true,
      label: 'Upload receipt',
      enabled: enabled,
      child: Material(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: enabled
                ? scheme.outlineVariant.withValues(alpha: 0.65)
                : scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPick : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: picking
                        ? SizedBox.square(
                            dimension: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: scheme.primary,
                            ),
                          )
                        : Icon(
                            Icons.add_a_photo_outlined,
                            size: 28,
                            color: enabled
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: 0.38),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  picking ? 'Preparing receipt…' : 'Upload receipt',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Item, quantity, price, and total are read from the image.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualEntryFields extends StatelessWidget {
  const _ManualEntryFields({
    required this.itemController,
    required this.quantityController,
    required this.priceController,
    required this.totalController,
  });

  final TextEditingController itemController;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final TextEditingController totalController;

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
              decoration: InputDecoration(
                labelText: 'Item',
                filled: true,
                fillColor: scheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _MinQuantityInputFormatter(),
                    ],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      filled: true,
                      fillColor: scheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Unit price',
                      filled: true,
                      fillColor: scheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: totalController,
              readOnly: true,
              enableInteractiveSelection: false,
              decoration: InputDecoration(
                labelText: 'Total',
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({
    required this.file,
    required this.filename,
    required this.onRemove,
  });

  final File file;
  final String filename;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                file,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 72,
                  height: 72,
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Receipt ready',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove receipt',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
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
