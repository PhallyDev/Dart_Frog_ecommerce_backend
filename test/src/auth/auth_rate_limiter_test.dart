import 'dart:io';

import 'package:shop_ease_ecommerce/src/auth/auth_rate_limiter.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:test/test.dart';

void main() {
  test('applies the login limit and includes Retry-After.', () {
    final address = 'test-client-${DateTime.now().microsecondsSinceEpoch}';
    for (var attempt = 0; attempt < 10; attempt++) {
      AuthRateLimiter.enforce(address, 'login');
    }

    try {
      AuthRateLimiter.enforce(address, 'login');
      fail('The request limit should be enforced.');
    } on ApiException catch (error) {
      expect(error.statusCode, HttpStatus.tooManyRequests);
      expect(error.headers['retry-after'], isNotNull);
    }
  });
}
