import 'package:dio/dio.dart';

import '../../../core/config/api_config.dart';

class AuthApi {
  Dio _client(String? bearer) {
    return Dio(
      BaseOptions(
        baseUrl: apiBaseUrl(),
        headers: apiRequestHeaders(authorizationBearer: bearer),
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final client = _client(null);
    final response = await client.post<Map<String, dynamic>>(
      '/api/v1/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final client = _client(null);
    final response = await client.post<Map<String, dynamic>>(
      '/api/v1/login',
      data: {'email': email, 'password': password},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
  }) async {
    final client = _client(null);
    final response = await client.post<Map<String, dynamic>>(
      '/api/v1/auth/google',
      data: {'id_token': idToken},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> dashboard({required String token}) async {
    final client = _client(token);
    final response = await client.get<Map<String, dynamic>>('/api/v1/dashboard');
    return response.data ?? <String, dynamic>{};
  }

  Future<void> logout({required String token}) async {
    final client = _client(token);
    await client.post<void>('/api/v1/logout');
  }
}
