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
  bool _pickingReceipt = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_syncTotal);
    _quantityController.addListener(_syncTotal);
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

  Future<void> _save() async {
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
        categoryId: _selectedCategoryId,
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 8, 24, bottomInset + safeBottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New expense', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<_ExpenseEntryMode>(
              segments: const [
                ButtonSegment(
                  value: _ExpenseEntryMode.receipt,
                  label: Text('Receipt'),
                  icon: Icon(Icons.receipt_long_outlined),
                ),
                ButtonSegment(
                  value: _ExpenseEntryMode.manual,
                  label: Text('Manual'),
                  icon: Icon(Icons.edit_outlined),
                ),
              ],
              selected: {_entryMode},
              onSelectionChanged: _saving
                  ? null
                  : (selection) => _setEntryMode(selection.first),
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              data: (categories) => InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedCategoryId,
                    isExpanded: true,
                    hint: const Text('None'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...categories.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _selectedCategoryId = v),
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              error: (Object error, StackTrace stackTrace) => InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  border: OutlineInputBorder(),
                  helperText: 'Could not load categories.',
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedCategoryId,
                    isExpanded: true,
                    hint: const Text('None'),
                    items: const [
                      DropdownMenuItem<int?>(value: null, child: Text('None')),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _selectedCategoryId = v),
                  ),
                ),
              ),
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
                        : const Icon(Icons.swap_horiz),
                    label: Text(
                      _pickingReceipt ? 'Preparing…' : 'Change receipt',
                    ),
                  ),
                ),
              ],
            ] else ...[
              _ManualEntryFields(
                itemController: _itemController,
                quantityController: _quantityController,
                priceController: _priceController,
                totalController: _totalController,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ||
                      (_entryMode == _ExpenseEntryMode.receipt &&
                          _receipt == null)
                  ? null
                  : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _entryMode == _ExpenseEntryMode.receipt
                          ? 'Save from receipt'
                          : 'Save expense',
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final enabled = !picking && !saving;

    return Material(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPick : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            children: [
              if (picking)
                SizedBox.square(
                  dimension: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colorScheme.primary,
                  ),
                )
              else
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 40,
                  color: enabled
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              const SizedBox(height: 12),
              Text(
                picking ? 'Preparing receipt…' : 'Upload receipt',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Item, quantity, price, and total are read from the image.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: itemController,
          textInputAction: TextInputAction.next,
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
        TextFormField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _MinQuantityInputFormatter(),
          ],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
          validator: (v) {
            final n = int.tryParse(v?.trim() ?? '');
            if (n == null || n < 1) {
              return 'Quantity must be at least 1.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Price',
            border: OutlineInputBorder(),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Enter a price.';
            }
            final n = num.tryParse(v.trim());
            if (n == null || n < 0) {
              return 'Enter a valid non-negative number.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: totalController,
          readOnly: true,
          enableInteractiveSelection: false,
          decoration: const InputDecoration(
            labelText: 'Total',
            border: OutlineInputBorder(),
          ),
        ),
      ],
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 64,
                  height: 64,
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Receipt selected', style: textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
