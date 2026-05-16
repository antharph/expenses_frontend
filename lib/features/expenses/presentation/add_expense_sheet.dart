import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/api_errors.dart';
import '../../auth/application/session_notifier.dart';
import '../application/categories_provider.dart';
import '../application/expenses_list_notifier.dart';
import '../data/expenses_api.dart';

class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({super.key});

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _itemController = TextEditingController();
  final _priceController = TextEditingController();
  XFile? _receipt;
  int? _selectedCategoryId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _itemController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String _filenameFromPath(String path) {
    final i = path.lastIndexOf(RegExp(r'[/\\]'));
    return i >= 0 ? path.substring(i + 1) : path;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _receipt = x;
      _error = null;
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
      final api = ref.read(expensesApiProvider);
      final receipt = _receipt;
      final hasReceipt = receipt != null && receipt.path.isNotEmpty;
      await api.createExpense(
        token: token,
        item: hasReceipt ? null : _itemController.text.trim(),
        price: hasReceipt ? null : _priceController.text.trim(),
        receiptFilePath: receipt?.path,
        receiptFilename: receipt != null ? _filenameFromPath(receipt.path) : null,
        categoryId: _selectedCategoryId,
      );
      await ref.read(expensesListProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense saved.')),
      );
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
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('None'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _selectedCategoryId = v),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _itemController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Item',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (_receipt != null) {
                  return null;
                }
                if (v == null || v.trim().isEmpty) {
                  return 'Enter an item name.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (_receipt != null) {
                  return null;
                }
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
            if (_receipt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Item and price will be read from the receipt.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(_receipt == null ? 'Upload receipt (optional)' : 'Change receipt'),
            ),
            if (_receipt != null) ...[
              const SizedBox(height: 8),
              Text(
                _filenameFromPath(_receipt!.path),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
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
      ),
    );
  }
}
