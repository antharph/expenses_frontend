import '../domain/auth_provider.dart';

class UserSession {
  const UserSession({
    required this.token,
    required this.name,
    required this.email,
    this.passwordAuthEnabled = true,
    this.authProvider = UserAuthProvider.email,
  });

  final String token;
  final String name;
  final String email;
  final bool passwordAuthEnabled;
  final UserAuthProvider authProvider;

  UserSession copyWith({
    String? token,
    String? name,
    String? email,
    bool? passwordAuthEnabled,
    UserAuthProvider? authProvider,
  }) {
    return UserSession(
      token: token ?? this.token,
      name: name ?? this.name,
      email: email ?? this.email,
      passwordAuthEnabled: passwordAuthEnabled ?? this.passwordAuthEnabled,
      authProvider: authProvider ?? this.authProvider,
    );
  }
}
