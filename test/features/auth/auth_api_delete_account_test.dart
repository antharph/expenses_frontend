import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expenses_frontend/features/auth/data/auth_api.dart';

void main() {
  group('AuthApi deleteAccount', () {
    test('sends password for email accounts', () async {
      Map<String, dynamic>? capturedBody;
      String? capturedMethod;
      String? capturedPath;

      final client = Dio(
        BaseOptions(baseUrl: 'http://test'),
      );
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            capturedMethod = options.method;
            capturedPath = options.path;
            handler.resolve(
              Response<void>(
                requestOptions: options,
              ),
            );
          },
        ),
      );

      final api = AuthApi(clientOverride: client);
      await api.deleteAccount(
        token: 'test-token',
        password: 'secret-password',
      );

      expect(capturedMethod, 'DELETE');
      expect(capturedPath, '/api/v1/user/account');
      expect(capturedBody, isNotNull);
      expect(capturedBody!['password'], 'secret-password');
    });

    test('omits body for social accounts', () async {
      Object? capturedBody;
      String? capturedMethod;

      final client = Dio(
        BaseOptions(baseUrl: 'http://test'),
      );
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data;
            capturedMethod = options.method;
            handler.resolve(
              Response<void>(
                requestOptions: options,
              ),
            );
          },
        ),
      );

      final api = AuthApi(clientOverride: client);
      await api.deleteAccount(token: 'test-token');

      expect(capturedMethod, 'DELETE');
      expect(capturedBody, isNull);
    });
  });
}
