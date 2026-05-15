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
    return error.message ?? 'Network error';
  }
  return error.toString();
}
