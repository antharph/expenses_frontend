import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_notifier.dart';
import '../data/expenses_api.dart';
import '../domain/expense_category.dart';

final expenseCategoriesProvider =
    FutureProvider.autoDispose<List<ExpenseCategory>>((ref) async {
  final token = ref.watch(sessionProvider).valueOrNull?.token;
  if (token == null || token.isEmpty) {
    return [];
  }

  return ref.read(expensesApiProvider).listCategories(token: token);
});
