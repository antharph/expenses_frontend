import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_notifier.dart';
import '../data/budgets_api.dart';
import '../domain/budget_type.dart';

final budgetTypesProvider =
    FutureProvider.autoDispose<List<BudgetType>>((ref) async {
  final token = ref.watch(sessionProvider).valueOrNull?.token;
  if (token == null || token.isEmpty) {
    return [];
  }

  return ref.read(budgetsApiProvider).listBudgetTypes(token: token);
});
