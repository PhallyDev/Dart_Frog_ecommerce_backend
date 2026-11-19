import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('OpenAPI spec documents the versioned feature routes.', () async {
    final spec = await File('docs/openapi.yaml').readAsString();

    expect(spec, startsWith('openapi: 3.1.0'));
    for (final path in [
      '/auth/signup:',
      '/products:',
      '/cart:',
      '/checkout/orders:',
      '/profile:',
      '/settings:',
    ]) {
      expect(spec, contains(path), reason: 'Missing OpenAPI path $path');
    }
  });
}
