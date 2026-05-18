import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../domain/expense_category.dart';

final expensesApiProvider = Provider<ExpensesApi>((ref) => ExpensesApi());

class ExpensesApi {
  Dio _jsonClient(String token) {
    return Dio(
      BaseOptions(
        baseUrl: apiBaseUrl(),
        headers: apiRequestHeaders(authorizationBearer: token),
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  Dio _multipartClient(String token) {
    final headers = Map<String, String>.from(
      apiRequestHeaders(authorizationBearer: token),
    )..remove('Content-Type');

    return Dio(
      BaseOptions(
        baseUrl: apiBaseUrl(),
        headers: headers,
        connectTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  }

  Future<Map<String, dynamic>> listExpenses({
    required String token,
    int page = 1,
    String? from,
    String? to,
  }) async {
    final client = _jsonClient(token);
    final queryParameters = <String, dynamic>{'page': page};
    if (from != null) {
      queryParameters['from'] = from;
    }
    if (to != null) {
      queryParameters['to'] = to;
    }
    final response = await client.get<Map<String, dynamic>>(
      '/api/v1/expenses',
      queryParameters: queryParameters,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> weeklyExpenses({
    required String token,
    required int year,
    required int week,
  }) async {
    final client = _jsonClient(token);
    final response = await client.get<Map<String, dynamic>>(
      '/api/v1/expenses/y/$year/w/$week',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<ExpenseCategory>> listCategories({required String token}) async {
    final client = _jsonClient(token);
    final response = await client.get<Map<String, dynamic>>('/api/v1/categories');
    final body = response.data ?? <String, dynamic>{};
    final raw = body['data'];
    if (raw is! List<dynamic>) {
      return [];
    }
    return raw
        .map(
          (e) => ExpenseCategory.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .where((c) => c.name.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> createExpense({
    required String token,
    String? item,
    int? quantity,
    String? price,
    String? receiptFilePath,
    String? receiptFilename,
    int? categoryId,
  }) async {
    final client = _multipartClient(token);
    final map = <String, dynamic>{};

    final hasReceipt = receiptFilePath != null && receiptFilePath.isNotEmpty;
    if (hasReceipt) {
      map['receipt'] = await MultipartFile.fromFile(
        receiptFilePath,
        filename: receiptFilename,
      );
    } else {
      map['item'] = item ?? '';
      map['quantity'] = '${quantity ?? 1}';
      map['price'] = price ?? '';
    }

    if (categoryId != null) {
      map['category_id'] = categoryId.toString();
    }

    final response = await client.post<Map<String, dynamic>>(
      '/api/v1/expenses',
      data: FormData.fromMap(map),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteExpense({
    required String token,
    required int id,
  }) async {
    final client = _jsonClient(token);
    await client.delete<void>('/api/v1/expenses/$id');
  }
}
