# Sign in with Apple — manual setup

Required before TestFlight / App Store builds. The Flutter app code and iOS entitlements are in the repo; these console steps must be done in Apple Developer (and optionally Firebase for Google only).

---

## How Apple sign-in works in this app

Apple **does not** go through Firebase Auth (that causes an audience mismatch when Firebase has a Services ID configured for Android).

| Step | iOS | Android |
| --- | --- | --- |
| 1 | Native Sign in with Apple sheet | Web OAuth via Services ID |
| 2 | Apple identity token (`aud` = `com.maiexpenses.app`) | Apple identity token (`aud` = `com.maiexpenses.service`) |
| 3 | `POST /api/v1/auth/apple` | Same endpoint |

The Laravel API verifies the Apple JWT directly (Apple JWKS) and accepts **both** audiences.

Google sign-in still uses Firebase → `POST /api/v1/auth/firebase`.

---

## Apple Developer portal

### App ID (iOS)

1. Open [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list).
2. Select App ID **`com.maiexpenses.app`**.
3. Enable **Sign In with Apple** capability and save.
4. Regenerate provisioning profiles if Xcode reports a capability mismatch.

### Services ID (Android)

1. Create a **Services ID** (e.g. **`com.maiexpenses.service`**).
2. Enable **Sign In with Apple** on the Services ID.
3. Configure it:
   - **Primary App ID:** `com.maiexpenses.app`
   - **Domains and Subdomains:** `personal-app-a61a2.firebaseapp.com`
   - **Return URLs:** `https://personal-app-a61a2.firebaseapp.com/__/auth/handler`

The return URL matches `lib/core/config/apple_auth_config.dart` (used by Android web OAuth).

### Sign in with Apple key (optional for this app)

Only required if you later use Firebase Auth for Apple on Android. **Not required** for the current direct-to-API flow.

---

## Firebase Console (Google only)

Firebase Apple provider settings (Services ID, Team ID, Key ID, private key) are **optional** for this app. Google Sign-In still requires Firebase.

Ensure the iOS app is registered with bundle ID **`com.maiexpenses.app`** and `GoogleService-Info.plist` matches.

---

## Backend (Laravel)

Optional env vars in `expenses` `.env` (defaults match production app):

```env
APPLE_BUNDLE_ID=com.maiexpenses.app
APPLE_SERVICES_ID=com.maiexpenses.service
```

Route: **`POST /api/v1/auth/apple`** — body: `id_token`, `timezone`, optional `name` (first sign-in).

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `audience in ID Token [com.maiexpenses.app] does not match the expected audience` | Old build still using Firebase Auth for Apple | **Stop app**, full `flutter run` (not hot restart); Apple must hit `/auth/apple`, not Firebase |
| `Invalid Apple token audience` from API | Backend `APPLE_*` env does not match token | Set `APPLE_BUNDLE_ID` and `APPLE_SERVICES_ID` in Laravel `.env` |
| `Apple token is missing an email claim` | User hid email and Apple did not share relay address | Retry sign-in; ensure `email` scope is requested |
| Android Apple fails | Services ID return URL mismatch | Verify return URL in Apple Developer matches `apple_auth_config.dart` |

---

## Verify locally

```bash
fvm flutter pub get
cd ios && pod install && cd ..
fvm flutter run -d 00008120-000E396A1479A01E \
  --dart-define-from-file=.config/config_local.json
```

**Important:** after auth code changes, quit the running app and run the command above again. Hot restart is not enough when switching auth flows.

On the login screen, confirm **Sign in with Apple** completes sign-in and lands on the dashboard with `auth_provider: apple`.

---

## App Store resubmission

1. Bump build number in `pubspec.yaml`.
2. `fvm flutter build ipa --dart-define-from-file=.config/config_prod.json`
3. Upload via Transporter.
4. Reply in App Store Connect Resolution Center that Sign in with Apple is offered alongside Google (Guideline 4.8).

Attach a login-screen screenshot showing both Sign in with Apple and Continue with Google if App Review requests it.
