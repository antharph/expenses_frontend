import 'package:flutter_timezone/flutter_timezone.dart';

/// Device IANA timezone (e.g. `Asia/Manila`), or `UTC` when unavailable.
Future<String> deviceTimezone() async {
  try {
    final timezone = await FlutterTimezone.getLocalTimezone();
    if (timezone.isNotEmpty) {
      return timezone;
    }
  } catch (_) {
    // Fall through to UTC.
  }

  return 'UTC';
}
