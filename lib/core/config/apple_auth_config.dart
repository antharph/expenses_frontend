/// Apple Sign In OAuth settings (Android web flow + Apple Developer Services ID).
///
/// iOS uses native Sign in with Apple (audience = bundle ID).
/// Android uses the web OAuth flow (audience = services ID).
/// Both send the Apple identity token to `POST /api/v1/auth/apple` — not Firebase Auth.
class AppleAuthConfig {
  AppleAuthConfig._();

  static const servicesId = String.fromEnvironment(
    'APPLE_SERVICES_ID',
    defaultValue: 'com.maiexpenses.service',
  );

  static const redirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
    defaultValue: 'https://personal-app-a61a2.firebaseapp.com/__/auth/handler',
  );
}
