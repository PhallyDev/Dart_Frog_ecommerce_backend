import 'dart:io';

import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

/// Converts URI query values to a map and rejects ambiguous repeated keys.
Map<String, String> singleQueryParameters(
  Map<String, List<String>> parameters,
) {
  final result = <String, String>{};
  for (final entry in parameters.entries) {
    if (entry.value.length != 1) {
      throw ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_query',
        message: 'Query parameter ${entry.key} must appear only once.',
      );
    }
    result[entry.key] = entry.value.single;
  }
  return result;
}

/// Rejects methods other than GET for read-only catalog routes.
void requireGet(String method) {
  if (method.toUpperCase() != 'GET') {
    throw const ApiException(
      statusCode: HttpStatus.methodNotAllowed,
      code: 'method_not_allowed',
      message: 'Only GET is supported for this endpoint.',
    );
  }
}
