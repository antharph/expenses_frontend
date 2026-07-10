import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'dart:io' show Platform;

import '../../../core/config/apple_auth_config.dart';

import '../../../core/errors/api_errors.dart';
import '../../../core/timezone/device_timezone.dart';
import '../../budget/data/budgets_api.dart';
import '../data/auth_api.dart';
import '../domain/auth_provider.dart';
import 'user_session.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi());

final sessionProvider = AsyncNotifierProvider<SessionNotifier, UserSession?>(
  SessionNotifier.new,
);

class SessionNotifier extends AsyncNotifier<UserSession?> {
  static const _tokenKey = 'auth_token';
  static const _nameKey = 'auth_user_name';
  static const _emailKey = 'auth_user_email';
  static const _passwordAuthEnabledKey = 'auth_password_auth_enabled';
  static const _authProviderKey = 'auth_provider';

  AuthApi get _api => ref.read(authApiProvider);

  @override
  Future<UserSession?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final data = await _api.dashboard(token: token);
      final user = data['user'] as Map<String, dynamic>?;
      if (user == null) {
        await _clearPrefs(prefs);
        return null;
      }
      final session = UserSession(
        token: token,
        name: user['name'] as String? ?? prefs.getString(_nameKey) ?? '',
        email: user['email'] as String? ?? prefs.getString(_emailKey) ?? '',
        passwordAuthEnabled: _parsePasswordAuthEnabled(
          user['password_auth_enabled'],
          prefs.getBool(_passwordAuthEnabledKey),
        ),
        authProvider: _parseAuthProvider(
          user['auth_provider'],
          prefs.getString(_authProviderKey) != null
              ? UserAuthProvider.fromApiValue(prefs.getString(_authProviderKey))
              : null,
        ),
      );
      await _persistUserFields(prefs, session);
      await _syncBudgetCycles(session);
      return session;
    } on DioException {
      await _clearPrefs(prefs);
      return null;
    }
  }

  /// Returns `null` on success, or a user-facing error message.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final timezone = await deviceTimezone();
      final data = await _api.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
        timezone: timezone,
      );
      final session = await _sessionFromAuthResponse(data);
      await _syncBudgetCycles(session);
      state = AsyncData(session);
      return null;
    } on DioException catch (e) {
      state = const AsyncData(null);
      return formatApiError(e);
    } catch (e) {
      state = const AsyncData(null);
      return e.toString();
    }
  }

  /// Returns `null` on success, or a user-facing error message.
  Future<String?> loginWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final timezone = await deviceTimezone();
      final data = await _api.login(
        email: email,
        password: password,
        timezone: timezone,
      );
      final session = await _sessionFromAuthResponse(data);
      await _syncBudgetCycles(session);
      state = AsyncData(session);
      return null;
    } on DioException catch (e) {
      state = const AsyncData(null);
      return formatApiError(e);
    } catch (e) {
      state = const AsyncData(null);
      return e.toString();
    }
  }

  /// Returns `null` on success, or a user-facing error message.
  Future<String?> loginWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: Platform.isAndroid
            ? WebAuthenticationOptions(
                clientId: AppleAuthConfig.servicesId,
                redirectUri: Uri.parse(AppleAuthConfig.redirectUri),
              )
            : null,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        state = const AsyncData(null);
        return 'Unable to read Apple identity token.';
      }

      final givenName = appleCredential.givenName?.trim() ?? '';
      final familyName = appleCredential.familyName?.trim() ?? '';
      final displayName = '$givenName $familyName'.trim();

      final timezone = await deviceTimezone();
      final data = await _api.loginWithApple(
        idToken: idToken,
        timezone: timezone,
        name: displayName.isEmpty ? null : displayName,
      );
      final session = await _sessionFromAuthResponse(data);
      await _syncBudgetCycles(session);
      state = AsyncData(session);
      return null;
    } on SignInWithAppleAuthorizationException catch (e) {
      state = const AsyncData(null);
      if (e.code == AuthorizationErrorCode.canceled) {
        return 'Apple sign-in was cancelled.';
      }
      return e.message;
    } on DioException catch (e) {
      state = const AsyncData(null);
      return formatApiError(e);
    } catch (e) {
      state = const AsyncData(null);
      return e.toString();
    }
  }

  /// Returns `null` on success, or a user-facing error message.
  Future<String?> loginWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) {
        state = const AsyncData(null);
        return 'Google sign-in was cancelled.';
      }

      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        state = const AsyncData(null);
        return 'Firebase user missing after Google sign-in.';
      }

      final idToken = await firebaseUser.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        state = const AsyncData(null);
        return 'Unable to read Firebase ID token.';
      }

      final timezone = await deviceTimezone();
      final data = await _api.loginWithFirebase(
        idToken: idToken,
        timezone: timezone,
      );
      final session = await _sessionFromAuthResponse(data);
      await _syncBudgetCycles(session);
      state = AsyncData(session);
      return null;
    } on DioException catch (e) {
      state = const AsyncData(null);
      return formatApiError(e);
    } catch (e) {
      state = const AsyncData(null);
      return e.toString();
    }
  }

  /// Returns `null` on success, or a user-facing error message.
  Future<String?> updateName({required String name}) async {
    final current = state.valueOrNull;
    if (current == null) {
      return 'Not signed in.';
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Enter your name.';
    }

    try {
      final data = await _api.updateProfile(token: current.token, name: trimmed);
      final user = data['user'] as Map<String, dynamic>?;
      final updated = current.copyWith(
        name: user?['name'] as String? ?? trimmed,
        passwordAuthEnabled: user != null
            ? _parsePasswordAuthEnabled(
                user['password_auth_enabled'],
                current.passwordAuthEnabled,
              )
            : current.passwordAuthEnabled,
        authProvider: user != null
            ? _parseAuthProvider(
                user['auth_provider'],
                current.authProvider,
              )
            : current.authProvider,
      );
      final prefs = await SharedPreferences.getInstance();
      await _persistUserFields(prefs, updated);
      state = AsyncData(updated);
      return null;
    } on DioException catch (e) {
      return formatApiError(e);
    } catch (e) {
      return e.toString();
    }
  }

  /// Refreshes the session from the dashboard endpoint.
  Future<void> refreshSession() async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    try {
      final data = await _api.dashboard(token: current.token);
      final user = data['user'] as Map<String, dynamic>?;
      if (user == null) {
        return;
      }

      final updated = current.copyWith(
        name: user['name'] as String? ?? current.name,
        email: user['email'] as String? ?? current.email,
        passwordAuthEnabled: _parsePasswordAuthEnabled(
          user['password_auth_enabled'],
          current.passwordAuthEnabled,
        ),
        authProvider: _parseAuthProvider(
          user['auth_provider'],
          current.authProvider,
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      await _persistUserFields(prefs, updated);
      state = AsyncData(updated);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await _clearPrefs(prefs);
        state = const AsyncData(null);
      }
    }
  }

  /// Returns `null` on success, or a user-facing error message.
  Future<String?> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    final current = state.valueOrNull;
    if (current == null) {
      return 'Not signed in.';
    }

    try {
      await _api.updatePassword(
        token: current.token,
        currentPassword: currentPassword,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      return null;
    } on DioException catch (e) {
      return formatApiError(e);
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    final current = state.valueOrNull;
    if (current != null) {
      try {
        await _api.logout(token: current.token);
      } on DioException {
        // Still clear local session if the token is already invalid.
      }
    }

    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();

    final prefs = await SharedPreferences.getInstance();
    await _clearPrefs(prefs);
    state = const AsyncData(null);
  }

  Future<UserSession> _sessionFromAuthResponse(
    Map<String, dynamic> data,
  ) async {
    final token = data['token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;
    if (token == null || token.isEmpty || user == null) {
      throw Exception('Unexpected auth response shape.');
    }

    final session = UserSession(
      token: token,
      name: user['name'] as String? ?? '',
      email: user['email'] as String? ?? '',
      passwordAuthEnabled: _parsePasswordAuthEnabled(
        user['password_auth_enabled'],
        null,
      ),
      authProvider: _parseAuthProvider(user['auth_provider'], null),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await _persistUserFields(prefs, session);

    return session;
  }

  Future<void> _syncBudgetCycles(UserSession session) async {
    try {
      await ref.read(budgetsApiProvider).syncBudgetCycles(token: session.token);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        rethrow;
      }
      // Keep the authenticated session if budget sync is temporarily unavailable.
    }
  }

  Future<void> _persistUserFields(
    SharedPreferences prefs,
    UserSession session,
  ) async {
    await prefs.setString(_nameKey, session.name);
    await prefs.setString(_emailKey, session.email);
    await prefs.setBool(_passwordAuthEnabledKey, session.passwordAuthEnabled);
    await prefs.setString(_authProviderKey, session.authProvider.name);
  }

  UserAuthProvider _parseAuthProvider(Object? apiValue, UserAuthProvider? cached) {
    if (apiValue != null) {
      return UserAuthProvider.fromApiValue(apiValue);
    }
    return cached ?? UserAuthProvider.email;
  }

  bool _parsePasswordAuthEnabled(Object? apiValue, bool? cached) {
    if (apiValue is bool) {
      return apiValue;
    }
    if (apiValue is int) {
      return apiValue != 0;
    }
    if (apiValue is String) {
      final normalized = apiValue.toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return cached ?? true;
  }

  Future<void> _clearPrefs(SharedPreferences prefs) async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_passwordAuthEnabledKey);
    await prefs.remove(_authProviderKey);
  }
}
