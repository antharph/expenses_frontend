import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_notifier.dart';
import '../../expenses/data/expenses_api.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_date.dart';
import '../domain/expense_week.dart';

class DailyExpenseTotal {
  const DailyExpenseTotal({
    required this.day,
    required this.total,
    this.isToday = false,
    this.isFuturePlaceholder = false,
  });

  final DateTime day;
  final double total;
  final bool isToday;
  final bool isFuturePlaceholder;
}

class CategoryExpenseTotal {
  const CategoryExpenseTotal({required this.label, required this.total});

  final String label;
  final double total;
}

class DashboardExpenseSummary {
  const DashboardExpenseSummary({
    required this.year,
    required this.week,
    required this.weekTotal,
    required this.dailyTotals,
    required this.categoryTotals,
    required this.startDate,
    required this.endDate,
  });

  final int year;
  final int week;
  final double weekTotal;
  final List<DailyExpenseTotal> dailyTotals;
  final List<CategoryExpenseTotal> categoryTotals;
  final DateTime startDate;
  final DateTime endDate;
}

const String kNoCategoryLabel = 'No Category';

String expenseCategoryLabel(Expense expense) {
  final name = expense.categoryName?.trim();
  if (name != null && name.isNotEmpty) {
    return name;
  }
  return kNoCategoryLabel;
}

/// Visible week on the dashboard (swipe updates this).
final dashboardSelectedWeekProvider = StateProvider<ExpenseWeekKey>((ref) {
  return ExpenseWeek.weekContaining(DateTime.now());
});

final dashboardExpenseSummaryProvider = FutureProvider.autoDispose
    .family<DashboardExpenseSummary, ExpenseWeekKey>((ref, weekKey) async {
      final token = ref.watch(sessionProvider).valueOrNull?.token;
      if (token == null) {
        return _emptySummaryForWeek(weekKey);
      }

      final api = ref.watch(expensesApiProvider);
      return _loadWeekSummary(api, token, weekKey);
    });

DashboardExpenseSummary _emptySummaryForWeek(ExpenseWeekKey weekKey) {
  final days = ExpenseWeek.daysInWeek(weekKey.year, weekKey.week);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final isCurrentWeek = ExpenseWeek.isCurrentCalendarWeek(
    weekKey.year,
    weekKey.week,
  );

  return DashboardExpenseSummary(
    year: weekKey.year,
    week: weekKey.week,
    weekTotal: 0,
    startDate: days.first,
    endDate: days.last,
    dailyTotals: days
        .map(
          (d) => DailyExpenseTotal(
            day: d,
            total: 0,
            isToday: _sameCalendarDay(d, today),
            isFuturePlaceholder: isCurrentWeek && d.isAfter(today),
          ),
        )
        .toList(),
    categoryTotals: const [],
  );
}

Future<DashboardExpenseSummary> _loadWeekSummary(
  ExpensesApi api,
  String token,
  ExpenseWeekKey weekKey,
) async {
  final body = await api.weeklyExpenses(
    token: token,
    year: weekKey.year,
    week: weekKey.week,
  );

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final isCurrentWeek = ExpenseWeek.isCurrentCalendarWeek(
    weekKey.year,
    weekKey.week,
  );

  final days = ExpenseWeek.daysInWeek(weekKey.year, weekKey.week);
  final byDay = {for (final d in days) d: 0.0};
  final byCategory = <String, double>{};

  final rawList = body['data'];
  final list = rawList is List<dynamic> ? rawList : const <dynamic>[];
  final expenses = list
      .map((e) => Expense.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  for (final e in expenses) {
    final day = expenseLocalDay(e.dateIso, referenceNow: now);
    if (day == null || !byDay.containsKey(day)) {
      continue;
    }
    final amount = double.tryParse(e.total) ?? 0;
    byDay[day] = (byDay[day] ?? 0) + amount;

    final label = expenseCategoryLabel(e);
    byCategory[label] = (byCategory[label] ?? 0) + amount;
  }

  final dailyTotals = days
      .map(
        (d) => DailyExpenseTotal(
          day: d,
          total: byDay[d] ?? 0,
          isToday: _sameCalendarDay(d, today),
          isFuturePlaceholder: isCurrentWeek && d.isAfter(today),
        ),
      )
      .toList();

  final categoryTotals = byCategory.entries
      .map((e) => CategoryExpenseTotal(label: e.key, total: e.value))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  final meta = body['meta'];
  var weekTotal = 0.0;
  DateTime startDate = days.first;
  DateTime endDate = days.last;
  if (meta is Map<String, dynamic>) {
    weekTotal = double.tryParse(meta['sum_total']?.toString() ?? '') ?? 0;
    startDate = _parseMetaDate(meta['start_date']) ?? startDate;
    endDate = _parseMetaDate(meta['end_date']) ?? endDate;
  }

  return DashboardExpenseSummary(
    year: weekKey.year,
    week: weekKey.week,
    weekTotal: weekTotal,
    startDate: startDate,
    endDate: endDate,
    dailyTotals: dailyTotals,
    categoryTotals: categoryTotals,
  );
}

bool _sameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime? _parseMetaDate(Object? raw) {
  if (raw == null) {
    return null;
  }
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) {
    return null;
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}
