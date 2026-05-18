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
  });

  final List<Expense> items;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final String? initialError;
  final bool hasMore;
  final int loadedPage;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;

  bool get hasDateFilter => dateRangeStart != null && dateRangeEnd != null;

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

  double get filteredTotal => sumExpenseTotals(filteredItems);

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

  /// Removes the expense locally on success; returns an error message on failure.
  Future<String?> deleteExpense(int id) async {
    final token = _token;
    if (token == null) {
      return 'Not signed in.';
    }

    try {
      await _api.deleteExpense(token: token, id: id);
      state = state.copyWith(
        items: state.items.where((e) => e.id != id).toList(),
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
    if (meta is Map<String, dynamic>) {
      final current = _asInt(meta['current_page']);
      final last = _asInt(meta['last_page']);
      if (current != null && last != null) {
        hasMore = current < last;
      }
    }

    return _ParsedPage(
      items: [...appendTo, ...newItems],
      hasMore: hasMore,
    );
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
  _ParsedPage({required this.items, required this.hasMore});

  final List<Expense> items;
  final bool hasMore;
}
