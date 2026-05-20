import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_errors.dart';
import '../../auth/application/session_notifier.dart';
import '../data/expenses_api.dart';
import '../domain/expense.dart';
import '../domain/expense_date.dart';

class ExpensesListState {
  const ExpensesListState({
    this.items = const [],
    this.isLoadingInitial = false,
    this.isLoadingMore = false,
    this.initialError,
    this.hasMore = true,
    this.loadedPage = 0,
    this.dateRangeStart,
    this.dateRangeEnd,
    this.aggregateTotalCount,
    this.aggregateSumTotal,
  });

  final List<Expense> items;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final String? initialError;
  final bool hasMore;
  final int loadedPage;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;

  /// Total matching expenses across all pages (`meta.total` from the API).
  final int? aggregateTotalCount;

  /// Sum of line totals for all matching expenses (`meta.sum_total` from the API).
  final double? aggregateSumTotal;

  bool get hasDateFilter => dateRangeStart != null && dateRangeEnd != null;

  bool get hasAggregateSummary =>
      aggregateTotalCount != null && aggregateSumTotal != null;

  List<Expense> get filteredItems {
    if (!hasDateFilter) {
      return items;
    }
    return items
        .where(
          (e) => expenseMatchesDateRange(
            e.dateIso,
            rangeStart: dateRangeStart,
            rangeEnd: dateRangeEnd,
          ),
        )
        .toList();
  }

  ExpensesListState copyWith({
    List<Expense>? items,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    String? initialError,
    bool clearInitialError = false,
    bool? hasMore,
    int? loadedPage,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    bool clearDateRange = false,
    int? aggregateTotalCount,
    double? aggregateSumTotal,
    bool clearAggregates = false,
  }) {
    return ExpensesListState(
      items: items ?? this.items,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      initialError: clearInitialError ? null : (initialError ?? this.initialError),
      hasMore: hasMore ?? this.hasMore,
      loadedPage: loadedPage ?? this.loadedPage,
      dateRangeStart: clearDateRange
          ? null
          : (dateRangeStart ?? this.dateRangeStart),
      dateRangeEnd: clearDateRange ? null : (dateRangeEnd ?? this.dateRangeEnd),
      aggregateTotalCount: clearAggregates
          ? null
          : (aggregateTotalCount ?? this.aggregateTotalCount),
      aggregateSumTotal: clearAggregates
          ? null
          : (aggregateSumTotal ?? this.aggregateSumTotal),
    );
  }
}

final expensesListProvider =
    NotifierProvider<ExpensesListNotifier, ExpensesListState>(ExpensesListNotifier.new);

class ExpensesListNotifier extends Notifier<ExpensesListState> {
  @override
  ExpensesListState build() => const ExpensesListState();

  ExpensesApi get _api => ref.read(expensesApiProvider);

  String? get _token => ref.read(sessionProvider).valueOrNull?.token;

  void setDateRange({DateTime? start, DateTime? end, bool clear = false}) {
    if (clear) {
      state = state.copyWith(clearDateRange: true);
      loadInitial();
      return;
    }

    var newStart = start != null ? _dateOnly(start) : state.dateRangeStart;
    var newEnd = end != null ? _dateOnly(end) : state.dateRangeEnd;
    state = state.copyWith(dateRangeStart: newStart, dateRangeEnd: newEnd);

    if (newStart == null || newEnd == null) {
      return;
    }
    if (newStart.isAfter(newEnd)) {
      final swapped = newStart;
      newStart = newEnd;
      newEnd = swapped;
      state = state.copyWith(dateRangeStart: newStart, dateRangeEnd: newEnd);
    }
    loadInitial();
  }

  void clearDateRange() {
    setDateRange(clear: true);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String? _apiDate(DateTime? value) {
    if (value == null) {
      return null;
    }
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> loadInitial() async {
    final token = _token;
    if (token == null) {
      return;
    }
    if (state.isLoadingInitial) {
      return;
    }

    state = state.copyWith(
      isLoadingInitial: true,
      clearInitialError: true,
      items: const [],
      loadedPage: 0,
      hasMore: true,
      clearAggregates: true,
    );

    try {
      final body = await _api.listExpenses(
        token: token,
        page: 1,
        from: _apiDate(state.dateRangeStart),
        to: _apiDate(state.dateRangeEnd),
      );
      final parsed = _parsePage(body, appendTo: const []);
      state = state.copyWith(
        isLoadingInitial: false,
        items: parsed.items,
        hasMore: parsed.hasMore,
        loadedPage: 1,
        aggregateTotalCount: parsed.aggregateTotalCount,
        aggregateSumTotal: parsed.aggregateSumTotal,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoadingInitial: false,
        initialError: formatApiError(e),
        hasMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingInitial: false,
        initialError: e.toString(),
        hasMore: false,
      );
    }
  }

  Future<void> loadMore() async {
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    final token = _token;
    if (token == null || !state.hasMore || state.isLoadingMore || state.isLoadingInitial) {
      return;
    }
    if (state.loadedPage == 0) {
      return;
    }

    final nextPage = state.loadedPage + 1;
    state = state.copyWith(isLoadingMore: true);

    try {
      final body = await _api.listExpenses(
        token: token,
        page: nextPage,
        from: _apiDate(state.dateRangeStart),
        to: _apiDate(state.dateRangeEnd),
      );
      final parsed = _parsePage(body, appendTo: state.items);
      state = state.copyWith(
        isLoadingMore: false,
        items: parsed.items,
        hasMore: parsed.hasMore,
        loadedPage: nextPage,
        aggregateTotalCount: parsed.aggregateTotalCount,
        aggregateSumTotal: parsed.aggregateSumTotal,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoadingMore: false, initialError: formatApiError(e));
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, initialError: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }

  /// Updates the expense locally on success; returns an error message on failure.
  Future<String?> updateExpense({
    required int id,
    required String item,
    required int quantity,
    required String price,
    required String transactionDate,
    required String transactionTime,
  }) async {
    final token = _token;
    if (token == null) {
      return 'Not signed in.';
    }

    final previous = state.items.where((e) => e.id == id).firstOrNull;
    if (previous == null) {
      return 'Expense not found.';
    }

    try {
      final body = await _api.updateExpense(
        token: token,
        id: id,
        item: item,
        quantity: quantity,
        price: price,
        transactionDate: transactionDate,
        transactionTime: transactionTime,
      );
      final updated = _parseSingleExpense(body);
      final oldTotal = double.tryParse(previous.total) ?? 0;
      final newTotal = double.tryParse(updated.total) ?? 0;
      final delta = newTotal - oldTotal;
      final nextSum = state.aggregateSumTotal != null
          ? state.aggregateSumTotal! + delta
          : null;

      state = state.copyWith(
        items: state.items.map((e) => e.id == id ? updated : e).toList(),
        aggregateSumTotal: nextSum,
      );
      return null;
    } on DioException catch (e) {
      return formatApiError(e);
    } catch (e) {
      return e.toString();
    }
  }

  Expense _parseSingleExpense(Map<String, dynamic> body) {
    final raw = body['data'];
    if (raw is Map) {
      return Expense.fromJson(Map<String, dynamic>.from(raw));
    }
    return Expense.fromJson(body);
  }

  /// Removes the expense locally on success; returns an error message on failure.
  Future<String?> deleteExpense(int id) async {
    final token = _token;
    if (token == null) {
      return 'Not signed in.';
    }

    try {
      await _api.deleteExpense(token: token, id: id);
      final removed = state.items.where((e) => e.id == id).firstOrNull;
      final removedAmount = removed != null
          ? (double.tryParse(removed.total) ?? 0)
          : 0.0;
      final nextCount = state.aggregateTotalCount != null
          ? (state.aggregateTotalCount! - 1).clamp(0, 1 << 30).toInt()
          : null;
      final nextSum = state.aggregateSumTotal != null
          ? (state.aggregateSumTotal! - removedAmount).clamp(0.0, double.infinity)
          : null;

      state = state.copyWith(
        items: state.items.where((e) => e.id != id).toList(),
        aggregateTotalCount: nextCount,
        aggregateSumTotal: nextSum,
      );
      return null;
    } on DioException catch (e) {
      return formatApiError(e);
    } catch (e) {
      return e.toString();
    }
  }

  _ParsedPage _parsePage(Map<String, dynamic> body, {required List<Expense> appendTo}) {
    final rawList = body['data'];
    final list = rawList is List<dynamic> ? rawList : const <dynamic>[];
    final newItems = list
        .map((e) => Expense.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final meta = body['meta'];
    var hasMore = false;
    int? aggregateTotalCount;
    double? aggregateSumTotal;
    if (meta is Map<String, dynamic>) {
      final current = _asInt(meta['current_page']);
      final last = _asInt(meta['last_page']);
      if (current != null && last != null) {
        hasMore = current < last;
      }
      aggregateTotalCount = _asInt(meta['total']);
      aggregateSumTotal = _parseSumTotal(meta['sum_total']);
    }

    return _ParsedPage(
      items: [...appendTo, ...newItems],
      hasMore: hasMore,
      aggregateTotalCount: aggregateTotalCount,
      aggregateSumTotal: aggregateSumTotal,
    );
  }

  double? _parseSumTotal(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
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
}

class _ParsedPage {
  _ParsedPage({
    required this.items,
    required this.hasMore,
    this.aggregateTotalCount,
    this.aggregateSumTotal,
  });

  final List<Expense> items;
  final bool hasMore;
  final int? aggregateTotalCount;
  final double? aggregateSumTotal;
}
