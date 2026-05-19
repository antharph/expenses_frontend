import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/budget_providers.dart';
import 'budget_history_screen.dart';
import 'budget_progress_card.dart';
import 'create_budget_sheet.dart';

const double _kBudgetsContentGutter = 24;

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  void _showCreateBudgetSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const CreateBudgetSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(dashboardBudgetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: budgetsAsync.maybeWhen(
        data: (budgets) => budgets.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showCreateBudgetSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('Create budget'),
              ),
        orElse: () => null,
      ),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(_kBudgetsContentGutter),
              child: _EmptyBudgetPrompt(
                onCreateBudget: () => _showCreateBudgetSheet(context),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              _kBudgetsContentGutter,
              12,
              _kBudgetsContentGutter,
              _kBudgetsContentGutter,
            ),
            itemCount: budgets.length,
            separatorBuilder: (context, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final budget = budgets[index];
              return BudgetProgressCard(
                budget: budget,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BudgetHistoryScreen(
                        budgetId: budget.id,
                        budgetName: budget.name,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(_kBudgetsContentGutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(dashboardBudgetsProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyBudgetPrompt extends StatelessWidget {
  const _EmptyBudgetPrompt({required this.onCreateBudget});

  final VoidCallback onCreateBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: scheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'No budgets yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create a budget to track what remains for each pay period.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onCreateBudget,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create budget'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
