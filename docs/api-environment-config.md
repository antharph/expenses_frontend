# API environment configuration

Base URL and virtual-host settings for the Laravel API. These keys were previously kept in a local `.env` file (see `.env.old`); the Flutter app reads them at **compile time** from **`.config/*.json`** via `--dart-define-from-file`.

---

## Variables

| Key | Purpose |
| --- | --- |
| `API_URL` | Base URL of the Laravel API (**no trailing slash**). All HTTP calls use `{API_URL}/api/v1/...`. |
| `API_HOST` | Optional HTTP `Host` header for vhost / SNI when the stack needs a server name (e.g. Docker Apache on an IP with `expenses.local`). |

Read in Dart: `lib/core/config/api_config.dart` (`apiBaseUrl()`, `apiRequestHeaders()`).

---

## `API_URL` by runtime

Use the URL that matches **where the app is running**, not where you edit code.

| Target | Typical `API_URL` | Notes |
| --- | --- | --- |
| **Android emulator** | `http://10.0.2.2:8080` | `10.0.2.2` is the emulator’s alias for the host machine’s `localhost`. |
| **iOS Simulator** | `http://127.0.0.1:8000` | Simulator shares the Mac’s network stack; use loopback when the API listens on the Mac. |
| **Physical device** | `http://192.168.0.39:8083` | Use your dev machine’s **LAN IP** and a port the device can reach on the same Wi‑Fi. Example from `.env.old`. |

On a physical device, `localhost` / `127.0.0.1` refers to **the device itself**, not your computer—use a routable LAN address instead.

---

## Example (physical device on LAN)

From `.env.old`:

```env
API_URL=http://192.168.0.39:8083
API_HOST=expenses.local
```

Equivalent JSON for this project (`.config/config_local.json`, gitignored):

```json
{
  "API_URL": "http://192.168.0.39:8083",
  "API_HOST": "expenses.local"
}
```

Copy **`.config/config_local.example.json`** to **`.config/config_local.json`** and adjust values for your machine and target device.

Production values live in **`.config/config_prod.json`** (committed).

---

## Run and build

Pass a define file on every run or build:

```bash
fvm flutter run --dart-define-from-file=.config/config_local.json
```

VS Code launch configs in `.vscode/launch.json` use the same pattern for Dev and Prod.

If `API_URL` is missing, the app throws at startup—see the error message in `apiBaseUrl()`.

---

## Related files

| Area | Path |
| --- | --- |
| Dart config | `lib/core/config/api_config.dart` |
| Local example | `.config/config_local.example.json` |
| Local overrides (gitignored) | `.config/config_local.json` |
| Production | `.config/config_prod.json` |
| Legacy reference | `.env.old` |
| Stack overview | `TECHNICAL_STACK.md` (API configuration section) |
