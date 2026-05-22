import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_errors.dart';
import '../../dashboard/presentation/sign_out_menu_button.dart';
import '../application/budget_providers.dart';
import '../domain/budget_progress.dart';
import 'budget_history_screen.dart';
import 'budget_list_skeleton.dart';
import 'budget_progress_card.dart';
import 'create_budget_sheet.dart';

const double _kBudgetsContentGutter = 20;

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  void _showCreateBudgetSheet(
    BuildContext context,
    List<BudgetProgress> budgets,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => CreateBudgetSheet(existingBudgets: budgets),
    );
  }

  Future<void> _refreshBudgets(WidgetRef ref) async {
    ref.invalidate(dashboardBudgetsProvider);
    await ref.read(dashboardBudgetsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(dashboardBudgetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: const [SignOutMenuButton()],
      ),
      floatingActionButton: budgetsAsync.maybeWhen(
        data: (budgets) => budgets.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showCreateBudgetSheet(context, budgets),
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
              child: Align(
                alignment: const Alignment(0, -0.2),
                child: _EmptyBudgetPrompt(
                  onCreateBudget: () =>
                      _showCreateBudgetSheet(context, budgets),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _refreshBudgets(ref),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                _kBudgetsContentGutter,
                8,
                _kBudgetsContentGutter,
                MediaQuery.paddingOf(context).bottom + 112,
              ),
              itemCount: budgets.length + 1,
              separatorBuilder: (context, index) {
                if (index == 0) {
                  return const SizedBox(height: 16);
                }
                return const SizedBox(height: 12);
              },
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _BudgetsSummaryHeader(budgets: budgets);
                }

                final budget = budgets[index - 1];
                return BudgetProgressCard(
                  budget: budget,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BudgetHistoryScreen(
                          budget: budget,
                          budgets: budgets,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const BudgetListSkeleton(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(_kBudgetsContentGutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'Could not load budgets',
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  formatApiError(error),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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

/// Screen-level hero — total remaining across active budgets.
class _BudgetsSummaryHeader extends StatelessWidget {
  const _BudgetsSummaryHeader({required this.budgets});

  final List<BudgetProgress> budgets;

  static final _amountFormat = NumberFormat.currency(
    symbol: r'',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final totalRemaining = budgets.fold<double>(
      0,
      (sum, budget) => sum + budget.remainingAmount,
    );
    final overCount = budgets.where((b) => b.isOverBudget).length;
    final budgetLabel = budgets.length == 1
        ? '1 budget'
        : '${budgets.length} budgets';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total remaining',
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _amountFormat.format(totalRemaining),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.1,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: totalRemaining < 0 ? scheme.error : scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          overCount > 0 ? '$budgetLabel · $overCount over limit' : budgetLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
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

    return Semantics(
      container: true,
      label:
          'No budgets yet. Create a budget to track what remains for each pay period.',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 28,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No budgets yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track what remains for each pay period and carry unused funds forward.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateBudget,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create budget'),
            ),
          ],
        ),
      ),
    );
  }
}
