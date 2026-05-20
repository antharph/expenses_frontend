/// Compile-time API settings from `--dart-define-from-file` (see `.config/*.json`).
///
/// On a **physical device**, `localhost` / `127.0.0.1` is the device itself—use
/// your dev machine's **LAN IP** and a server bound to `0.0.0.0`.
/// See `.config/config_local.example.json`.
String apiBaseUrl() {
  const raw = String.fromEnvironment('API_URL');
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw StateError(
      'API_URL is missing. Run with --dart-define-from-file=.config/config_local.json '
      '(or config_prod.json). See .config/config_local.example.json.',
    );
  }
  return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
}

/// Default headers for every API call (Dio [BaseOptions.headers]).
///
/// When `API_HOST` is set via dart-define, sends `Host: <value>` for vhost / SNI
/// routing (e.g. Docker Apache hitting an IP but needing a server name).
Map<String, String> apiRequestHeaders({String? authorizationBearer}) {
  final headers = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (authorizationBearer != null) 'Authorization': 'Bearer $authorizationBearer',
  };

  const host = String.fromEnvironment('API_HOST');
  final trimmedHost = host.trim();
  if (trimmedHost.isNotEmpty) {
    headers['Host'] = trimmedHost;
  }

  return headers;
}
