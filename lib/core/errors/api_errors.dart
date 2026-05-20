import 'package:dio/dio.dart';

/// Human-readable message from a failed API call (e.g. Laravel 422 validation).
String formatApiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      if (data['errors'] is Map) {
        final errors = data['errors'] as Map;
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }
          if (value is String && value.isNotEmpty) {
            return value;
          }
        }
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }

    if (_isUnreachableHost(error)) {
      return '${error.message ?? 'Connection failed'}\n\n'
          'On a physical phone, 127.0.0.1 and localhost refer to the phone, not your dev machine. '
          'Use your computer\'s LAN IP in .config/config_local.json API_URL (same Wi‑Fi), e.g. http://192.168.1.10:8080. '
          'Ensure the API listens on all interfaces (e.g. 0.0.0.0 in Docker/Apache), not only localhost.';
    }

    return error.message ?? 'Network error';
  }
  return error.toString();
}

bool _isUnreachableHost(DioException error) {
  if (error.type == DioExceptionType.connectionError) {
    return true;
  }
  final msg = error.message?.toLowerCase() ?? '';
  if (msg.contains('connection refused') ||
      msg.contains('failed host lookup') ||
      msg.contains('network is unreachable')) {
    return true;
  }
  return false;
}
