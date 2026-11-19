import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

/// Converts request failures to a consistent JSON response without leaking
/// unexpected exception details.
Response apiErrorResponse(Object error, StackTrace stackTrace) {
  if (error case final ApiException exception) {
    return Response.json(
      statusCode: exception.statusCode,
      headers: exception.headers,
      body: {
        'error': {
          'code': exception.code,
          'message': exception.message,
        },
      },
    );
  }

  stderr.writeln('Unhandled request error:\n$stackTrace');
  return Response.json(
    statusCode: HttpStatus.internalServerError,
    body: const {
      'error': {
        'code': 'internal_server_error',
        'message': 'An unexpected error occurred.',
      },
    },
  );
}
