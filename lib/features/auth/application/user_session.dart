class UserSession {
  const UserSession({
    required this.token,
    required this.name,
    required this.email,
    this.passwordAuthEnabled = true,
  });

  final String token;
  final String name;
  final String email;
  final bool passwordAuthEnabled;

  UserSession copyWith({
    String? token,
    String? name,
    String? email,
    bool? passwordAuthEnabled,
  }) {
    return UserSession(
      token: token ?? this.token,
      name: name ?? this.name,
      email: email ?? this.email,
      passwordAuthEnabled: passwordAuthEnabled ?? this.passwordAuthEnabled,
    );
  }
}
