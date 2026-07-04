enum UserAuthProvider {
  email,
  google,
  apple,
  facebook;

  static UserAuthProvider fromApiValue(Object? value) {
    if (value is String) {
      return switch (value) {
        'google' => UserAuthProvider.google,
        'apple' => UserAuthProvider.apple,
        'facebook' => UserAuthProvider.facebook,
        _ => UserAuthProvider.email,
      };
    }

    return UserAuthProvider.email;
  }

  String get socialSignInMessage {
    return switch (this) {
      UserAuthProvider.google =>
        'You signed in with Google. Password is managed by Google.',
      UserAuthProvider.apple =>
        'You signed in with Apple. Password is managed by Apple.',
      UserAuthProvider.facebook =>
        'You signed in with Facebook. Password is managed by Facebook.',
      UserAuthProvider.email =>
        'Password changes are not available for this account.',
    };
  }
}
