import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../domain/budget_log_entry.dart';
import '../domain/budget_progress.dart';
import '../domain/budget_type.dart';

final budgetsApiProvider = Provider<BudgetsApi>((ref) => BudgetsApi());

class BudgetsApi {
  BudgetsApi({Dio? clientOverride}) : _clientOverride = clientOverride;

  final Dio? _clientOverride;

  Dio _client(String token) {
    if (_clientOverride != null) {
      _clientOverride.options.headers.addAll(
        apiRequestHeaders(authorizationBearer: token),
      );
      return _clientOverride;
    }

    return Dio(
      BaseOptions(
        baseUrl: apiBaseUrl(),
        headers: apiRequestHeaders(authorizationBearer: token),
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  Future<List<BudgetProgress>> listBudgets({required String token}) async {
    final response = await _client(
      token,
    ).get<Map<String, dynamic>>('/api/v1/budgets');
    final body = response.data ?? <String, dynamic>{};
    final raw = body['data'];
    if (raw is! List<dynamic>) {
      return [];
    }
    return raw
        .map(
          (e) => BudgetProgress.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<BudgetType>> listBudgetTypes({required String token}) async {
    final response = await _client(
      token,
    ).get<Map<String, dynamic>>('/api/v1/budget-types');
    final body = response.data ?? <String, dynamic>{};
    final raw = body['data'];
    if (raw is! List<dynamic>) {
      return [];
    }
    return raw
        .map(
          (e) => BudgetType.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<BudgetProgress>> syncBudgetCycles({required String token}) async {
    final response = await _client(
      token,
    ).post<Map<String, dynamic>>('/api/v1/budgets/sync-cycles');
    final body = response.data ?? <String, dynamic>{};
    final raw = body['data'];
    if (raw is! List<dynamic>) {
      return [];
    }
    return raw
        .map(
          (e) => BudgetProgress.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<BudgetProgress> createBudget({
    required String token,
    required int budgetTypeId,
    required String name,
    String? amount,
    required String resetType,
    List<int>? resetDays,
    String? startDate,
    bool rollover = false,
    List<int> categoryIds = const [],
  }) async {
    final response = await _client(token).post<Map<String, dynamic>>(
      '/api/v1/budgets',
      data: <String, dynamic>{
        'budget_type_id': budgetTypeId,
        'name': name,
        'amount': amount,
        'reset_type': resetType,
        'reset_days': resetDays,
        'start_date': startDate,
        'rollover': rollover,
        'category_ids': categoryIds,
      },
    );
    final body = response.data ?? <String, dynamic>{};
    final data = body['data'];
    return BudgetProgress.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<BudgetProgress> finalizeManualBudget({
    required String token,
    required int budgetId,
  }) async {
    final response = await _client(
      token,
    ).post<Map<String, dynamic>>('/api/v1/budgets/$budgetId/finalize');
    final body = response.data ?? <String, dynamic>{};
    final data = body['data'];
    return BudgetProgress.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> deleteBudget({
    required String token,
    required int budgetId,
  }) async {
    await _client(token).delete<void>('/api/v1/budgets/$budgetId');
  }

  Future<BudgetProgress> updateBudgetCategories({
    required String token,
    required int budgetId,
    required List<int> categoryIds,
  }) async {
    final response = await _client(token).patch<Map<String, dynamic>>(
      '/api/v1/budgets/$budgetId/categories',
      data: <String, dynamic>{'category_ids': categoryIds},
    );
    final body = response.data ?? <String, dynamic>{};
    final data = body['data'];
    return BudgetProgress.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<BudgetLogEntry>> listBudgetLogs({
    required String token,
    required int budgetId,
  }) async {
    final response = await _client(
      token,
    ).get<Map<String, dynamic>>('/api/v1/budgets/$budgetId/logs');
    final body = response.data ?? <String, dynamic>{};
    final raw = body['data'];
    if (raw is! List<dynamic>) {
      return [];
    }
    return raw
        .map(
          (e) => BudgetLogEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }
}
