import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_notifier.dart';
import '../data/budgets_api.dart';
import '../domain/budget_log_entry.dart';
import '../domain/budget_progress.dart';

final dashboardBudgetsProvider =
    FutureProvider.autoDispose<List<BudgetProgress>>((ref) async {
      final token = ref.watch(sessionProvider).valueOrNull?.token;
      if (token == null) {
        return [];
      }
      return ref.watch(budgetsApiProvider).listBudgets(token: token);
    });

final budgetLogsProvider = FutureProvider.autoDispose
    .family<List<BudgetLogEntry>, int>((ref, budgetId) async {
      final token = ref.watch(sessionProvider).valueOrNull?.token;
      if (token == null) {
        return [];
      }
      return ref
          .watch(budgetsApiProvider)
          .listBudgetLogs(token: token, budgetId: budgetId);
    });
