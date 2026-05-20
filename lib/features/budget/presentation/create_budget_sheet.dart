import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_errors.dart';
import '../../auth/application/session_notifier.dart';
import '../../expenses/application/categories_provider.dart';
import '../application/budget_providers.dart';
import '../data/budgets_api.dart';

enum _BudgetResetOption {
  semiMonthly('date_fixed', '1st and 16th', [1, 16]),
  monthly('date_fixed', 'Monthly', [1]),
  weekly('interval', 'Weekly', [7]),
  manual('manual', 'Manual', null);

  const _BudgetResetOption(this.apiValue, this.label, this.resetDays);

  final String apiValue;
  final String label;
  final List<int>? resetDays;
}

class CreateBudgetSheet extends ConsumerStatefulWidget {
  const CreateBudgetSheet({super.key});

  @override
  ConsumerState<CreateBudgetSheet> createState() => _CreateBudgetSheetState();
}

class _CreateBudgetSheetState extends ConsumerState<CreateBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final Set<int> _selectedCategoryIds = {};

  _BudgetResetOption _resetOption = _BudgetResetOption.semiMonthly;
  bool _rollover = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedCategoryIds.isEmpty) {
      setState(() => _error = 'Select at least one category.');
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
      await ref
          .read(budgetsApiProvider)
          .createBudget(
            token: token,
            name: _nameController.text.trim(),
            amount: _amountController.text.trim(),
            resetType: _resetOption.apiValue,
            resetDays: _resetOption.resetDays,
            rollover: _rollover,
            categoryIds: _selectedCategoryIds.toList(),
          );
      ref.invalidate(dashboardBudgetsProvider);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Budget created.')));
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 8, 24, bottomInset + safeBottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create budget', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Track spending by pay period and carry unused funds forward.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Budget name',
                hintText: 'Home Budget',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Enter a budget name.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Base amount',
                hintText: '5000',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (value) {
                final amount = double.tryParse((value ?? '').trim());
                if (amount == null || amount <= 0) {
                  return 'Enter an amount greater than 0.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_BudgetResetOption>(
              initialValue: _resetOption,
              decoration: const InputDecoration(
                labelText: 'Reset cadence',
                border: OutlineInputBorder(),
              ),
              items: _BudgetResetOption.values
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _resetOption = value);
                    },
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable rollover'),
              subtitle: const Text('Unused funds move into the next period.'),
              value: _rollover,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _rollover = value),
            ),
            const SizedBox(height: 4),
            Text(
              'Categories',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return Text(
                    'No categories available. Add categories before creating a budget.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final category in categories)
                      FilterChip(
                        label: Text(category.name),
                        selected: _selectedCategoryIds.contains(category.id),
                        onSelected: _saving
                            ? null
                            : (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategoryIds.add(category.id);
                                  } else {
                                    _selectedCategoryIds.remove(category.id);
                                  }
                                });
                              },
                      ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => Text(
                'Could not load categories. Categories are required.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create budget'),
            ),
          ],
        ),
      ),
    );
  }
}
