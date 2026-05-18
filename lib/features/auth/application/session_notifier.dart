import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/api_errors.dart';
import '../../../core/timezone/device_timezone.dart';
import '../data/auth_api.dart';
import 'user_session.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi());

final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, UserSession?>(SessionNotifier.new);

class SessionNotifier extends AsyncNotifier<UserSession?> {
  static const _tokenKey = 'auth_token';
  static const _nameKey = 'auth_user_name';
  static const _emailKey = 'auth_user_email';

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
      );
      await _persistUserFields(prefs, session);
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
      final data = await _api.loginWithGoogle(
        idToken: idToken,
        timezone: timezone,
      );
      final session = await _sessionFromAuthResponse(data);
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

  Future<UserSession> _sessionFromAuthResponse(Map<String, dynamic> data) async {
    final token = data['token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;
    if (token == null || token.isEmpty || user == null) {
      throw Exception('Unexpected auth response shape.');
    }

    final session = UserSession(
      token: token,
      name: user['name'] as String? ?? '',
      email: user['email'] as String? ?? '',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await _persistUserFields(prefs, session);

    return session;
  }

  Future<void> _persistUserFields(
    SharedPreferences prefs,
    UserSession session,
  ) async {
    await prefs.setString(_nameKey, session.name);
    await prefs.setString(_emailKey, session.email);
  }

  Future<void> _clearPrefs(SharedPreferences prefs) async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_emailKey);
  }
}
