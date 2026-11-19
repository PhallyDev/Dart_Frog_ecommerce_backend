import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../routes/api/v1/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  group('GET /api/v1', () {
    test('returns the versioned service status as JSON.', () async {
      final response = route.onRequest(_MockRequestContext());
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(
        body,
        equals({
          'status': 'ok',
          'service': 'ShopEase Ecommerce API',
          'version': 'v1',
        }),
      );
    });
  });
}
