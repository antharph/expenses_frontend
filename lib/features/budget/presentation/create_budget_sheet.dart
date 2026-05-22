import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_errors.dart';
import '../../auth/application/session_notifier.dart';
import '../../expenses/application/categories_provider.dart';
import '../../expenses/domain/expense_category.dart';
import '../application/budget_providers.dart';
import '../data/budgets_api.dart';
import '../domain/budget_progress.dart';

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
  const CreateBudgetSheet({super.key, this.existingBudgets = const []});

  final List<BudgetProgress> existingBudgets;

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
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Budget created.')));
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

  Set<int> get _assignedCategoryIds {
    return widget.existingBudgets
        .expand((budget) => budget.categories)
        .map((category) => category.id)
        .toSet();
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottomInset + safeBottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create budget',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Track spending by pay period and carry unused funds forward.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _BudgetDetailsSection(
              saving: _saving,
              nameController: _nameController,
              amountController: _amountController,
              resetOption: _resetOption,
              rollover: _rollover,
              fieldDecoration: _fieldDecoration,
              onResetChanged: (value) => setState(() => _resetOption = value),
              onRolloverChanged: (value) => setState(() => _rollover = value),
            ),
            const SizedBox(height: 16),
            _BudgetCategoryField(
              categoriesAsync: categoriesAsync,
              selectedCategoryIds: _selectedCategoryIds,
              disabledCategoryIds: _assignedCategoryIds,
              enabled: !_saving,
              onChanged: (categoryId, selected) {
                setState(() {
                  if (selected) {
                    _selectedCategoryIds.add(categoryId);
                  } else {
                    _selectedCategoryIds.remove(categoryId);
                  }
                  _error = null;
                });
              },
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
                      'Create budget',
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

class EditBudgetCategoriesSheet extends ConsumerStatefulWidget {
  const EditBudgetCategoriesSheet({
    super.key,
    required this.budget,
    required this.existingBudgets,
  });

  final BudgetProgress budget;
  final List<BudgetProgress> existingBudgets;

  @override
  ConsumerState<EditBudgetCategoriesSheet> createState() =>
      _EditBudgetCategoriesSheetState();
}

class _EditBudgetCategoriesSheetState
    extends ConsumerState<EditBudgetCategoriesSheet> {
  late final Set<int> _selectedCategoryIds;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedCategoryIds = widget.budget.categories
        .map((category) => category.id)
        .toSet();
  }

  Set<int> get _assignedCategoryIds {
    return widget.existingBudgets
        .where((budget) => budget.id != widget.budget.id)
        .expand((budget) => budget.categories)
        .map((category) => category.id)
        .toSet();
  }

  Future<void> _save() async {
    if (_selectedCategoryIds.isEmpty) {
      setState(() => _error = 'Keep at least one category selected.');
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
      final updatedBudget = await ref
          .read(budgetsApiProvider)
          .updateBudgetCategories(
            token: token,
            budgetId: widget.budget.id,
            categoryIds: _selectedCategoryIds.toList(),
          );
      ref.invalidate(dashboardBudgetsProvider);
      ref.invalidate(budgetLogsProvider(widget.budget.id));
      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.pop(updatedBudget);
      messenger.showSnackBar(
        const SnackBar(content: Text('Budget categories updated.')),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottomInset + safeBottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit categories',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose the categories this budget should track. At least one category must remain selected.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _BudgetCategoryField(
            categoriesAsync: categoriesAsync,
            selectedCategoryIds: _selectedCategoryIds,
            disabledCategoryIds: _assignedCategoryIds,
            enabled: !_saving,
            onChanged: (categoryId, selected) {
              setState(() {
                if (selected) {
                  _selectedCategoryIds.add(categoryId);
                } else if (_selectedCategoryIds.length > 1) {
                  _selectedCategoryIds.remove(categoryId);
                }
                _error = null;
              });
            },
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
                    'Save categories',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BudgetDetailsSection extends StatelessWidget {
  const _BudgetDetailsSection({
    required this.saving,
    required this.nameController,
    required this.amountController,
    required this.resetOption,
    required this.rollover,
    required this.fieldDecoration,
    required this.onResetChanged,
    required this.onRolloverChanged,
  });

  final bool saving;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final _BudgetResetOption resetOption;
  final bool rollover;
  final InputDecoration Function(
    BuildContext, {
    required String label,
    String? hint,
  })
  fieldDecoration;
  final ValueChanged<_BudgetResetOption> onResetChanged;
  final ValueChanged<bool> onRolloverChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: nameController,
              enabled: !saving,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration(
                context,
                label: 'Budget name',
                hint: 'Home food',
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
              controller: amountController,
              enabled: !saving,
              decoration: fieldDecoration(
                context,
                label: 'Base amount',
                hint: '5000',
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
              initialValue: resetOption,
              decoration: fieldDecoration(context, label: 'Reset cadence'),
              items: _BudgetResetOption.values
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              onChanged: saving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      onResetChanged(value);
                    },
            ),
            const SizedBox(height: 4),
            Material(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text(
                  'Enable rollover',
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Text(
                  'Unused funds move into the next period.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                value: rollover,
                onChanged: saving ? null : onRolloverChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCategoryField extends StatelessWidget {
  const _BudgetCategoryField({
    required this.categoriesAsync,
    required this.selectedCategoryIds,
    required this.disabledCategoryIds,
    required this.enabled,
    required this.onChanged,
  });

  final AsyncValue<List<ExpenseCategory>> categoriesAsync;
  final Set<int> selectedCategoryIds;
  final Set<int> disabledCategoryIds;
  final bool enabled;
  final void Function(int categoryId, bool selected) onChanged;

  List<ExpenseCategory> _orderedCategories(List<ExpenseCategory> categories) {
    final sorted = List<ExpenseCategory>.from(categories)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select at least one category to track. Categories already used by another active budget are unavailable.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
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

            final ordered = _orderedCategories(categories);

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in ordered) ...[
                  Builder(
                    builder: (context) {
                      final selected = selectedCategoryIds.contains(
                        category.id,
                      );
                      final disabledByBudget = disabledCategoryIds.contains(
                        category.id,
                      );
                      final isLastSelected =
                          selected && selectedCategoryIds.length == 1;
                      final canChange =
                          enabled && !disabledByBudget && !isLastSelected;

                      return _CategoryChoiceChip(
                        label: category.name,
                        selected: selected,
                        accent: _categoryAccent(scheme, category.name),
                        enabled: canChange,
                        disabledReason: disabledByBudget
                            ? 'Already used'
                            : isLastSelected
                            ? 'Required'
                            : null,
                        onTap: () => onChanged(category.id, !selected),
                      );
                    },
                  ),
                ],
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
            'Could not load categories. Categories are required.',
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
    this.disabledReason,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final bool enabled;
  final String? disabledReason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final muted = !enabled && !selected;
    final foregroundColor = selected
        ? scheme.onPrimaryContainer
        : muted
        ? scheme.onSurfaceVariant.withValues(alpha: 0.55)
        : scheme.onSurfaceVariant;

    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : muted
          ? scheme.surfaceContainerLow.withValues(alpha: 0.55)
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
                    color: muted
                        ? scheme.outline.withValues(alpha: 0.45)
                        : selected
                        ? scheme.primary
                        : accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _displayLabel(label),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foregroundColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (disabledReason != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    disabledReason!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                ],
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
