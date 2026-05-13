# Technical stack — Expenses Frontend

This document records the **intended** languages, frameworks, and services for the Flutter client. The backend remains the **system of record** for expenses; the app consumes **HTTP APIs** for business data (see `AGENTS.md` for product flows).

## Core platform

| Area | Choice |
|------|--------|
| **Framework** | [Flutter](https://flutter.dev/) |
| **Target platforms** | **iOS** and **Android** (single codebase; platform-specific setup where Firebase, signing, or networking require it) |
| **Language** | Dart (see `pubspec.yaml` → `environment.sdk` for the supported range) |
| **UI system** | [Material Design 3](https://m3.material.io/) (Material 3 widgets and theming in Flutter) |
| **State management** | [Riverpod](https://riverpod.dev/) (`flutter_riverpod`; optional `riverpod_annotation` + `riverpod_generator` for codegen) |
| **Flutter SDK pinning** | [FVM](https://fvm.app/) (Flutter Version Management) |

## Flutter version management (FVM)

- **Pin** the Flutter SDK version the team builds and ships with (for example via `.fvm/fvm_config.json` and an `.fvmrc` if you use that workflow).
- **Install FVM:** follow [FVM installation](https://fvm.app/documentation/getting-started/installation).
- **Day-to-day:** prefer `fvm flutter …` and `fvm dart …` (or a shell alias) so CI and every developer use the **same** Flutter engine and Dart SDK.
- **CI:** install FVM (or cache the FVM-resolved Flutter path) and invoke `fvm flutter pub get`, `fvm flutter analyze`, `fvm flutter test`, and `fvm flutter build` so pipelines match local machines.

Until FVM is committed to the repo, document the chosen Flutter version here or in `README.md` when the team sets it.

## UI — Material Design 3

- Enable Material 3 on the app theme (for example `ThemeData(useMaterial3: true)` on `MaterialApp`).
- Prefer **M3-aligned** components and patterns: `ColorScheme` (including dynamic color on Android where product allows it), updated navigation bars, chips, cards, and typography roles from `TextTheme`.
- Keep **spacing, motion, and elevation** consistent with the active theme rather than hardcoding legacy Material 2-only patterns unless there is a deliberate exception.

## State management — Riverpod

- Wrap the app with `ProviderScope` and expose feature and session state through providers.
- Use **`AsyncValue`** for asynchronous work (API calls, auth transitions).
- Keep **side effects** (sign-in, HTTP mutations) in notifiers / services invoked from providers, not buried in `build` methods.
- Optional: **`@riverpod` + codegen** for larger provider graphs; run `dart run build_runner build --delete-conflicting-outputs` when using generators.

## Authentication — Firebase (Google Sign-In)

- Use **Firebase** for identity, with **Google** as the sign-in method:
  - [Firebase Core](https://firebase.google.com/docs/flutter/setup) for app initialization.
  - [Firebase Authentication](https://firebase.google.com/docs/auth/flutter/start) with the **Google** provider.
- **Typical Flutter packages:** `firebase_core`, `firebase_auth`, and the Google sign-in flow recommended in current Firebase Flutter docs (often involving `google_sign_in` where required by the platform integration).
- **Configuration:** `GoogleService-Info.plist` (iOS), `google-services.json` (Android), and web OAuth client configuration as documented by Firebase. Do not commit secrets that should stay in CI or local developer config; follow Firebase’s guidance for each platform.
- **Backend API:** after Firebase establishes the user session, attach whatever **ID token or session contract** your API expects on each HTTP call (see `AGENTS.md`).

## Data and networking

- **REST (or documented HTTP) client** for expenses, chat actions, receipt upload, and listings—**all authoritative data from the API** unless offline-first is explicitly added later.
- Central **API base URL**, timeouts, interceptors (auth header, logging in debug), and typed repositories or data sources.
- **Receipt images:** `multipart/form-data` or the format required by the API; handle size limits and permission UX on the device.

### Configuration (.env)

- **Local and non-secret settings** (API endpoints, host hints for TLS/SNI or logging) live in a **`.env`** file at the project root, loaded at app startup (typically via a package such as `flutter_dotenv`, with `.env` listed under `flutter.assets` in `pubspec.yaml`).
- **Do not commit** machine-specific `.env` files if they embed LAN IPs or personal hostnames; commit a **`.env.example`** with the same keys and placeholder values instead.
- **Defined keys** (names are stable; values are environment-specific):

| Key | Purpose |
|-----|---------|
| `API_URL` | Base URL for HTTP calls to the backend (scheme, host, port, no trailing slash unless your client code expects it). |
| `API_HOST` | Hostname associated with the API (e.g. for virtual hosts, certificate validation, or `Host` header behavior if your stack uses it). |

- **Example (iOS, physical device on a LAN)** — the device must reach a **routable IP** on your network; this is **not** necessarily correct for the **iOS Simulator** (simulator often uses `localhost` / `127.0.0.1` or your Mac’s loopback depending on where the API listens):

  ```env
  API_URL=http://192.168.0.39:8083
  API_HOST=expenses.local
  ```

- **iOS Simulator:** often differs from a physical device (e.g. API bound to `127.0.0.1` on the Mac vs. a LAN IP). Adjust `API_URL` (and if needed `API_HOST`) so the simulator’s network view can reach the server.
- **Android:** emulator vs. physical device also differs (e.g. Android Emulator’s special alias **`10.0.2.2`** to reach the host machine’s `localhost`). Use an `API_URL` (and `API_HOST` if applicable) that matches **that** runtime, not necessarily the iOS LAN example above.

## Tooling and quality

| Tool | Role |
|------|------|
| **Analyzer / lints** | `analysis_options.yaml` + `flutter_lints` |
| **Formatting** | `dart format` |
| **Tests** | `flutter test`, widget tests for critical UI |

## Optional packages (add when needed)

The following are **common** companions; versions belong in `pubspec.yaml`, not duplicated here.

- **HTTP:** `dio` or `http`, plus small API/repository layer.
- **Serialization:** `freezed`, `json_serializable`, `build_runner` if you adopt immutable DTOs.
- **Routing:** `go_router` when navigation grows beyond a few routes.
- **Environment:** primary contract is a **`.env`** file (see [Configuration (.env)](#configuration-env)); `flutter_dotenv` (or equivalent) is the usual loader. **`--dart-define`** remains an option for CI or flavors when you do not ship a bundled `.env`.

## Related docs

- [`AGENTS.md`](./AGENTS.md) — product flows, architecture expectations, and guidance for contributors and AI assistants.
