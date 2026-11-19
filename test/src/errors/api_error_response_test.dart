import 'dart:convert';
import 'dart:io';

import 'package:shop_ease_ecommerce/src/errors/api_error_response.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:test/test.dart';

void main() {
  test('serializes expected API errors consistently.', () async {
    final response = apiErrorResponse(
      const ApiException(
        statusCode: HttpStatus.notFound,
        code: 'not_found',
        message: 'Resource not found.',
      ),
      StackTrace.current,
    );
    final body = jsonDecode(await response.body()) as Map<String, dynamic>;

    expect(response.statusCode, HttpStatus.notFound);
    expect(
      body,
      equals({
        'error': {
          'code': 'not_found',
          'message': 'Resource not found.',
        },
      }),
    );
  });

  test('does not expose unexpected error details in responses.', () async {
    final response = apiErrorResponse(
      StateError('sensitive database detail'),
      StackTrace.current,
    );
    final body = await response.body();

    expect(response.statusCode, HttpStatus.internalServerError);
    expect(body, isNot(contains('sensitive database detail')));
    expect(body, contains('unexpected error'));
  });
}
