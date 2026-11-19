import 'dart:io';

import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

/// Per-process fixed-window limiter for sensitive authentication endpoints.
abstract final class AuthRateLimiter {
  static final Map<String, _RateWindow> _windows = {};
  static const _window = Duration(minutes: 15);

  /// Enforces an endpoint-specific request limit for a remote client address.
  static void enforce(String remoteAddress, String endpoint) {
    final limit = switch (endpoint) {
      'login' => 10,
      'signup' => 5,
      'forgot-password' => 5,
      'reset-password' => 5,
      'verify-email' => 10,
      'resend-verification' => 5,
      _ => 30,
    };
    final now = DateTime.now().toUtc();
    final key = '$remoteAddress:$endpoint';
    final current = _windows[key];
    if (current == null || !now.isBefore(current.startedAt.add(_window))) {
      _windows[key] = _RateWindow(startedAt: now, requests: 1);
      if (_windows.length > 4096) {
        _windows.removeWhere(
          (_, value) => !now.isBefore(value.startedAt.add(_window)),
        );
      }
      return;
    }

    if (current.requests >= limit) {
      final retryAfter = current.startedAt.add(_window).difference(now);
      throw ApiException(
        statusCode: HttpStatus.tooManyRequests,
        code: 'rate_limit_exceeded',
        message: 'Too many authentication requests. Try again later.',
        headers: {
          'retry-after': '${(retryAfter.inMilliseconds + 999) ~/ 1000}',
        },
      );
    }
    current.requests++;
  }
}

class _RateWindow {
  _RateWindow({required this.startedAt, required this.requests});

  final DateTime startedAt;
  int requests;
}
