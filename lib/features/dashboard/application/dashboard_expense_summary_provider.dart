import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_notifier.dart';
import '../../expenses/data/expenses_api.dart';
import '../../expenses/domain/expense.dart';

class DailyExpenseTotal {
  const DailyExpenseTotal({required this.day, required this.total});

  final DateTime day;
  final double total;
}

class DashboardExpenseSummary {
  const DashboardExpenseSummary({
    required this.todayTotal,
    required this.dailyTotals,
  });

  final double todayTotal;
  final List<DailyExpenseTotal> dailyTotals;
}

final dashboardExpenseSummaryProvider =
    FutureProvider.autoDispose<DashboardExpenseSummary>((ref) async {
      final token = ref.watch(sessionProvider).valueOrNull?.token;
      if (token == null) {
        return _emptySummaryForLocalToday();
      }

      final api = ref.watch(expensesApiProvider);
      return _loadSummary(api, token);
    });

DashboardExpenseSummary _emptySummaryForLocalToday() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final rangeStart = today.subtract(const Duration(days: 6));
  return DashboardExpenseSummary(
    todayTotal: 0,
    dailyTotals: List.generate(
      7,
      (i) =>
          DailyExpenseTotal(day: rangeStart.add(Duration(days: i)), total: 0),
    ),
  );
}

Future<DashboardExpenseSummary> _loadSummary(
  ExpensesApi api,
  String token,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final rangeStart = today.subtract(const Duration(days: 6));

  final accumulated = <Expense>[];
  var page = 1;
  var hasMore = true;

  while (hasMore) {
    final body = await api.listExpenses(token: token, page: page);
    final parsed = _parsePage(body);
    accumulated.addAll(parsed.items);

    DateTime? minDayOnPage;
    for (final e in parsed.items) {
      final day = _expenseLocalDay(e.dateIso, now);
      if (day != null && (minDayOnPage == null || day.isBefore(minDayOnPage))) {
        minDayOnPage = day;
      }
    }

    hasMore = parsed.hasMore;
    if (!hasMore) {
      break;
    }
    if (minDayOnPage != null && minDayOnPage.isBefore(rangeStart)) {
      break;
    }
    page++;
  }

  final byDay = <DateTime, double>{};
  for (var i = 0; i < 7; i++) {
    byDay[rangeStart.add(Duration(days: i))] = 0;
  }

  for (final e in accumulated) {
    final day = _expenseLocalDay(e.dateIso, now);
    if (day == null) {
      continue;
    }
    if (day.isBefore(rangeStart) || day.isAfter(today)) {
      continue;
    }
    final price = double.tryParse(e.price) ?? 0;
    byDay[day] = (byDay[day] ?? 0) + price;
  }

  final dailyTotals = List<DailyExpenseTotal>.generate(7, (i) {
    final d = rangeStart.add(Duration(days: i));
    return DailyExpenseTotal(day: d, total: byDay[d] ?? 0);
  });

  return DashboardExpenseSummary(
    todayTotal: byDay[today] ?? 0,
    dailyTotals: dailyTotals,
  );
}

DateTime? _expenseLocalDay(String raw, DateTime referenceNow) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final iso = DateTime.tryParse(trimmed);
  if (iso != null) {
    final local = iso.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  final parts = trimmed.split('/');
  if (parts.length != 2) {
    return null;
  }
  final month = int.tryParse(parts[0].trim());
  final day = int.tryParse(parts[1].trim());
  if (month == null ||
      day == null ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31) {
    return null;
  }

  var year = referenceNow.year;
  var candidate = DateTime(year, month, day);
  if (candidate.isAfter(referenceNow)) {
    year -= 1;
    candidate = DateTime(year, month, day);
  }
  return DateTime(candidate.year, candidate.month, candidate.day);
}

class _ParsedPage {
  _ParsedPage({required this.items, required this.hasMore});

  final List<Expense> items;
  final bool hasMore;
}

_ParsedPage _parsePage(Map<String, dynamic> body) {
  final rawList = body['data'];
  final list = rawList is List<dynamic> ? rawList : const <dynamic>[];
  final items = list
      .map((e) => Expense.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  final meta = body['meta'];
  var hasMore = false;
  if (meta is Map<String, dynamic>) {
    final current = _asInt(meta['current_page']);
    final last = _asInt(meta['last_page']);
    if (current != null && last != null) {
      hasMore = current < last;
    }
  }

  return _ParsedPage(items: items, hasMore: hasMore);
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}
