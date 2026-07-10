import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expenses_frontend/features/auth/data/auth_api.dart';

void main() {
  group('AuthApi timezone payload', () {
    test('loginWithApple sends id_token, timezone, and optional name', () async {
      Map<String, dynamic>? capturedBody;

      final client = Dio(
        BaseOptions(baseUrl: 'http://test'),
      );
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'token': 'test-token',
                  'user': {
                    'id': 1,
                    'name': 'Test User',
                    'email': 'test@example.com',
                    'password_auth_enabled': false,
                    'auth_provider': 'apple',
                  },
                },
              ),
            );
          },
        ),
      );

      final api = AuthApi(clientOverride: client);
      await api.loginWithApple(
        idToken: 'apple-jwt',
        timezone: 'Asia/Manila',
        name: 'Anthony Araneta',
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!['id_token'], 'apple-jwt');
      expect(capturedBody!['timezone'], 'Asia/Manila');
      expect(capturedBody!['name'], 'Anthony Araneta');
    });

    test('loginWithFirebase sends id_token and timezone', () async {
      Map<String, dynamic>? capturedBody;

      final client = Dio(
        BaseOptions(baseUrl: 'http://test'),
      );
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'token': 'test-token',
                  'user': {
                    'id': 1,
                    'name': 'Test User',
                    'email': 'test@example.com',
                    'password_auth_enabled': false,
                    'auth_provider': 'apple',
                  },
                },
              ),
            );
          },
        ),
      );

      final api = AuthApi(clientOverride: client);
      await api.loginWithFirebase(
        idToken: 'firebase-jwt',
        timezone: 'Asia/Manila',
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!['id_token'], 'firebase-jwt');
      expect(capturedBody!['timezone'], 'Asia/Manila');
    });

    test('login sends timezone', () async {
      Map<String, dynamic>? capturedBody;

      final client = Dio(
        BaseOptions(baseUrl: 'http://test'),
      );
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'token': 'test-token',
                  'user': {
                    'id': 1,
                    'name': 'Test User',
                    'email': 'test@example.com',
                    'password_auth_enabled': true,
                    'auth_provider': 'email',
                  },
                },
              ),
            );
          },
        ),
      );

      final api = AuthApi(clientOverride: client);
      await api.login(
        email: 'test@example.com',
        password: 'secret',
        timezone: 'America/New_York',
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!['timezone'], 'America/New_York');
    });

    test('register sends timezone', () async {
      Map<String, dynamic>? capturedBody;

      final client = Dio(
        BaseOptions(baseUrl: 'http://test'),
      );
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'token': 'test-token',
                  'user': {
                    'id': 1,
                    'name': 'Test User',
                    'email': 'test@example.com',
                    'password_auth_enabled': true,
                    'auth_provider': 'email',
                  },
                },
              ),
            );
          },
        ),
      );

      final api = AuthApi(clientOverride: client);
      await api.register(
        name: 'Test User',
        email: 'test@example.com',
        password: 'secret',
        passwordConfirmation: 'secret',
        timezone: 'Europe/London',
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!['timezone'], 'Europe/London');
    });
  });
}
