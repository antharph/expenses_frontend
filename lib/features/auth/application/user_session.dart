class UserSession {
  const UserSession({
    required this.token,
    required this.name,
    required this.email,
  });

  final String token;
  final String name;
  final String email;

  UserSession copyWith({String? token, String? name, String? email}) {
    return UserSession(
      token: token ?? this.token,
      name: name ?? this.name,
      email: email ?? this.email,
    );
  }
}
