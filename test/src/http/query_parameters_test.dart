import 'dart:io';

import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/http/query_parameters.dart';
import 'package:test/test.dart';

void main() {
  test('converts single query values to a map.', () {
    expect(
      singleQueryParameters({
        'page': ['2'],
        'sort': ['price_asc'],
      }),
      {'page': '2', 'sort': 'price_asc'},
    );
  });

  test('rejects repeated query parameters as ambiguous.', () {
    expect(
      () => singleQueryParameters({
        'page': ['1', '2'],
      }),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          HttpStatus.badRequest,
        ),
      ),
    );
  });

  test('allows GET only on read-only catalog endpoints.', () {
    expect(() => requireGet('GET'), returnsNormally);
    expect(
      () => requireGet('POST'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          HttpStatus.methodNotAllowed,
        ),
      ),
    );
  });
}
