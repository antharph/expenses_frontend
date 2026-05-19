import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../domain/budget_log_entry.dart';
import '../domain/budget_progress.dart';

final budgetsApiProvider = Provider<BudgetsApi>((ref) => BudgetsApi());

class BudgetsApi {
  Dio _client(String token) {
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

  Future<BudgetProgress> createBudget({
    required String token,
    required String name,
    required String amount,
    required String resetType,
    List<int>? resetDays,
    bool rollover = false,
    List<int> categoryIds = const [],
  }) async {
    final response = await _client(token).post<Map<String, dynamic>>(
      '/api/v1/budgets',
      data: <String, dynamic>{
        'name': name,
        'amount': amount,
        'reset_type': resetType,
        'reset_days': resetDays,
        'rollover': rollover,
        'category_ids': categoryIds,
      },
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
