import 'package:dio/dio.dart';

import '../../../core/config/api_config.dart';

class AuthApi {
  AuthApi({Dio? clientOverride}) : _clientOverride = clientOverride;

  final Dio? _clientOverride;

  Dio _client(String? bearer) {
    if (_clientOverride != null) {
      return _clientOverride;
    }

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
    required String timezone,
  }) async {
    final client = _client(null);
    final response = await client.post<Map<String, dynamic>>(
      '/api/v1/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'timezone': timezone,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String timezone,
  }) async {
    final client = _client(null);
    final response = await client.post<Map<String, dynamic>>(
      '/api/v1/login',
      data: {'email': email, 'password': password, 'timezone': timezone},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    required String timezone,
  }) async {
    final client = _client(null);
    final response = await client.post<Map<String, dynamic>>(
      '/api/v1/auth/google',
      data: {'id_token': idToken, 'timezone': timezone},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> dashboard({required String token}) async {
    final client = _client(token);
    final response = await client.get<Map<String, dynamic>>(
      '/api/v1/dashboard',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> logout({required String token}) async {
    final client = _client(token);
    await client.post<void>('/api/v1/logout');
  }
}
