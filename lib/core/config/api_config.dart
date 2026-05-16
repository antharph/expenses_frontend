import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Base URL for API calls (from `.env` `API_URL`).
///
/// On a **physical device**, `localhost` / `127.0.0.1` is the device itself—use
/// your dev machine's **LAN IP** and a server bound to `0.0.0.0`. See `.env.example`.
String apiBaseUrl() {
  final raw = dotenv.env['API_URL']?.trim();
  if (raw == null || raw.isEmpty) {
    throw StateError('API_URL is missing. Copy .env.example to .env and set API_URL.');
  }
  return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
}

/// Default headers for every API call (Dio [BaseOptions.headers]).
///
/// When `API_HOST` is set in `.env`, sends `Host: <value>` for vhost / SNI
/// routing (e.g. Docker Apache hitting an IP but needing a server name).
Map<String, String> apiRequestHeaders({String? authorizationBearer}) {
  final headers = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (authorizationBearer != null) 'Authorization': 'Bearer $authorizationBearer',
  };

  final host = dotenv.env['API_HOST']?.trim();
  if (host != null && host.isNotEmpty) {
    headers['Host'] = host;
  }

  return headers;
}
