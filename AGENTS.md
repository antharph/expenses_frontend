# AGENTS.md — Expenses Frontend

Guidance for AI assistants and contributors working on this repository. Treat this project as a **production-quality Flutter client**: clear architecture, predictable state, and safe network usage.

## Product overview

- **Purpose:** Users **track personal expenses**. Every expense record the user cares about is ultimately **owned and returned by the backend API** (this app is not the system of record).
- **Authentication:** Users sign in with **Google Sign-In**. After sign-in, attach the resulting **identity / session token** (or whatever contract the API defines) to API requests; do not treat the client as logged in until both Google and the API session are valid.
- **Primary interaction — chatbox:** A conversational UI is the main surface for working with expenses:
  - **Receipt image:** The user can **upload an image of a receipt** from the chatbox. The client should send it to the API (for example as **multipart/form-data** or the format the API specifies); parsing, extraction, and persistence are server responsibilities unless the API explicitly requires client-side steps.
  - **Manual entry:** The user can **type an item and price** in the chatbox; that payload is **saved through the API** (no ad-hoc local-only “saved” state).
  - **List expenses:** The user can **ask to see their expenses** in the chatbox; the **list is loaded from the API** and rendered in context (messages, attachments, or companion widgets — follow existing UX patterns once present).
- **Data rule:** **All authoritative expense data** (create, update, list, totals if shown) comes from **API responses**. Local storage is at most cache or draft UX, not a second source of truth, unless the product explicitly adds offline-first behavior later.

## Role of this codebase

- **Frontend only.** The app loads, displays, and mutates data exposed by **HTTP API endpoints** (another service owns persistence and business rules).
- Prefer **thin UI**: widgets compose layout and react to state; they do not embed raw endpoint URLs, ad-hoc `http` calls, or JSON parsing scattered across screens.

## State management: Riverpod

- Use **[Riverpod](https://riverpod.dev/)** as the single source of truth for app and feature state.
- **Do not** introduce alternative global state patterns (e.g. `ChangeNotifier` + `Provider` only, `GetX`, `Bloc`/`Cubit`, or heavy `setState` trees for shared data) unless there is an explicit product decision and this file is updated.
- **Recommended stack** (align new code with this as the project grows):
  - `flutter_riverpod` at the root (`ProviderScope`).
  - Prefer **`@riverpod` / `riverpod_annotation` + `riverpod_generator`** for providers that benefit from codegen (families, async, clear dependencies). Run `dart run build_runner build --delete-conflicting-outputs` when generators are in use.
  - Use **`AsyncValue`** for loading / data / error from APIs; surface errors in UI with retry where it makes sense.
- **Dependency direction:** UI → providers → repositories/services → HTTP client. Avoid providers that import widgets or `BuildContext` for business logic.

## API and data layer

- Centralize **base URL**, timeouts, and default headers (e.g. **auth after Google Sign-In**, API version) in one place (environment / config + client wrapper).
- Use a small **repository** (or “data source”) per domain area (e.g. expenses, chat / assistant turns if the API models them) that maps HTTP responses to **immutable models** (e.g. `freezed` + `json_serializable` if adopted). Receipt upload and “save line item” actions should go through the same style of API boundary, not inline in chat widgets.
- Handle **HTTP failures** explicitly: map status codes and parse errors to typed failures or `AsyncValue.error`, not silent `null` returns.
- Do not hardcode secrets in source; use `--dart-define`, CI secrets, or platform-specific secure storage for tokens as the app matures.

## Flutter and Dart practices

- Follow **[Effective Dart](https://dart.dev/effective-dart)** and project **`analysis_options.yaml`** / `flutter_lints`.
- Prefer **`const`** constructors where possible; keep `build` methods cheap and side-effect free.
- Use **`ThemeData` / `ColorScheme`** and typography from the theme rather than one-off magic numbers when building real screens.
- Prefer **null-safe**, explicit types on public APIs; avoid `dynamic` unless JSON boundaries require it and it is contained.
- **Navigation:** use `go_router` or Navigator 2.0 patterns if routing grows beyond a few screens; keep route names and arguments typed when practical.

## Project layout (evolve toward this)

As features land, organize by **capability** under `lib/` rather than a single `main.dart`:

- `lib/main.dart` — bootstrap, `ProviderScope`, app widget.
- `lib/app/` — theme, router, app-level widgets.
- `lib/core/` — shared config, HTTP client, errors, extensions.
- `lib/features/<feature>/` — UI, feature-specific providers, and repositories that belong together. Expect at least **auth** (Google), **expenses**, and **chat** (receipt upload, manual entry, list intent) to map cleanly into features or subfolders as the codebase grows.

Adjust names to match existing folders if the tree diverges; keep the **dependency direction** the same.

## Testing and quality

- Add **widget tests** for critical flows and **unit tests** for repositories and pure logic.
- Run **`flutter analyze`** before considering work complete; fix new analyzer issues introduced by changes.
- When using codegen, ensure generated files are committed or CI runs `build_runner` consistently (pick one team convention).

## What agents should optimize for

1. **Correctness** — models match API contracts; errors are visible and recoverable.
2. **Maintainability** — one obvious place for API calls and Riverpod providers per feature.
3. **UX** — loading and empty states for async data; avoid blocking the UI thread with heavy sync work.

When requirements are ambiguous, prefer **small, reviewable changes** that match the patterns above over large speculative refactors.
