# User timezone on registration and sign-in

The Laravel API stores each user’s display timezone in **`users.timezone`** (IANA identifier, e.g. `Asia/Manila`). Expense list filters, weekly views, and `date` / `transaction_at` formatting on the API all use that value—not app config or `DEFAULT_TIMEZONE`.

The Flutter client must send the device timezone on every flow that **creates** a user or should **refresh** timezone after sign-in.

---

## Resolving the device timezone (client)

| Piece | Location |
| --- | --- |
| Entry point | `lib/core/timezone/device_timezone.dart` → `deviceTimezone()` |
| Package | `flutter_timezone` (`FlutterTimezone.getLocalTimezone()`) |
| Fallback | `UTC` when the native call fails or returns empty (often means iOS/Android plugin not linked—see rebuild note below) |

Always call **`await deviceTimezone()`** in the session layer—do not hardcode `UTC` or read timezone from `.env`.

After adding `flutter_timezone`, run **`fvm flutter pub get`** and **`cd ios && pod install`**, then a **full rebuild** (not hot reload only).

---

## API endpoints that accept `timezone`

Base URL: `{API_URL}/api/v1` (see `.env` `API_URL`).  
Backend contract details: `expenses` repo → `docs/api/authentication.md`.

| Flow | HTTP | Path | Sends `timezone`? | Backend behavior |
| --- | --- | --- | --- | --- |
| Email registration | `POST` | `/register` | **Yes** | Set on create (defaults to `UTC` if omitted) |
| Google sign-in | `POST` | `/auth/google` | **Yes** | Set on create; **updated** on later sign-ins when sent |
| Email / password login | `POST` | `/login` | **Yes** | **Updated** on sign-in when sent |
| Session restore | `GET` | `/dashboard` | **No** | Read-only; no timezone in body |
| Logout | `POST` | `/logout` | **No** | N/A |

### Request body: `timezone`

| Field | Type | Required | Example |
| --- | --- | --- | --- |
| `timezone` | string | Optional on API; **required from this app** on register, login, and Google sign-in | `Asia/Manila` |

Validation on the API: IANA identifier, max 255 characters. Invalid values fall back to `UTC` server-side.

### Flows that send `timezone` (current implementation)

#### 1. Registration

- **UI:** `lib/features/auth/presentation/register_screen.dart` → `SessionNotifier.register`
- **API client:** `AuthApi.register` → `POST /api/v1/register`
- **JSON body includes:** `name`, `email`, `password`, `password_confirmation`, **`timezone`**

#### 2. Email / password login

- **UI:** `lib/features/auth/presentation/login_screen.dart` → `SessionNotifier.loginWithPassword`
- **API client:** `AuthApi.login` → `POST /api/v1/login`
- **JSON body includes:** `email`, `password`, **`timezone`**

#### 3. Google sign-in

- **UI:** `lib/features/auth/presentation/login_screen.dart` → `SessionNotifier.loginWithGoogle`
- **API client:** `AuthApi.loginWithGoogle` → `POST /api/v1/auth/google`
- **JSON body includes:** `id_token` (Firebase JWT), **`timezone`**

---

## Checklist: adding a new registration or sign-in method

When you add any new way to register or sign in (Apple, magic link, another OAuth provider, etc.):

1. **Backend** (`expenses` repo): accept optional `timezone` on the new auth endpoint; persist via `User::normalizeTimezone()` on create and update when appropriate. Document the field in `docs/api/authentication.md`.
2. **`AuthApi`:** add a `timezone` parameter to the new method; include `'timezone': timezone` in the POST JSON body.
3. **`SessionNotifier`:** `final timezone = await deviceTimezone();` before the API call; pass it into `AuthApi`.
4. **This file:** add a row to the table above and a short subsection under “Flows that send `timezone`”.
5. **Tests:** extend `test/features/auth/auth_api_timezone_test.dart` (or equivalent) so the new method’s request body includes `timezone`.
6. **Native plugins:** if a new package needs iOS pods, run `pod install` and document any rebuild requirement here.

All current sign-in paths (email/password, Google) refresh `users.timezone` when the client sends `timezone`.

---

## Related files (quick index)

| Area | Path |
| --- | --- |
| Timezone helper | `lib/core/timezone/device_timezone.dart` |
| HTTP auth API | `lib/features/auth/data/auth_api.dart` |
| Session / sign-in orchestration | `lib/features/auth/application/session_notifier.dart` |
| Auth API tests | `test/features/auth/auth_api_timezone_test.dart` |
| Backend auth docs | `../Codev/Codev-Docker/docker-lamp-stack/apache-www/expenses/docs/api/authentication.md` |
