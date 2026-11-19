import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

/// Reads a bounded JSON object request body.
Future<Map<String, Object?>> readJsonObject(RequestContext context) async {
  final contentType = context.request.headers['content-type'];
  if (contentType == null ||
      contentType.split(';').first.trim().toLowerCase() != 'application/json') {
    throw const ApiException(
      statusCode: HttpStatus.unsupportedMediaType,
      code: 'unsupported_media_type',
      message: 'Content-Type must be application/json.',
    );
  }

  final builder = BytesBuilder(copy: false);
  var length = 0;
  await for (final chunk in context.request.bytes()) {
    length += chunk.length;
    if (length > 16384) {
      throw const ApiException(
        statusCode: 413,
        code: 'request_too_large',
        message: 'JSON request bodies must not exceed 16 KB.',
      );
    }
    builder.add(chunk);
  }

  try {
    final decoded = jsonDecode(utf8.decode(builder.takeBytes()));
    if (decoded is! Map) {
      throw const FormatException('JSON request body must be an object.');
    }
    return Map<String, Object?>.from(decoded);
  } on FormatException {
    throw const ApiException(
      statusCode: HttpStatus.badRequest,
      code: 'invalid_json',
      message: 'Request body must be a valid JSON object.',
    );
  }
}

/// Reads a bounded UTF-8 request body without changing bytes used for signing.
Future<String> readRawJsonBody(RequestContext context) async {
  final contentType = context.request.headers['content-type'];
  if (contentType == null ||
      contentType.split(';').first.trim().toLowerCase() != 'application/json') {
    throw const ApiException(
      statusCode: HttpStatus.unsupportedMediaType,
      code: 'unsupported_media_type',
      message: 'Content-Type must be application/json.',
    );
  }
  final builder = BytesBuilder(copy: false);
  var length = 0;
  await for (final chunk in context.request.bytes()) {
    length += chunk.length;
    if (length > 16384) {
      throw const ApiException(
        statusCode: 413,
        code: 'request_too_large',
        message: 'JSON request bodies must not exceed 16 KB.',
      );
    }
    builder.add(chunk);
  }
  try {
    return utf8.decode(builder.takeBytes());
  } on FormatException {
    throw const ApiException(
      statusCode: HttpStatus.badRequest,
      code: 'invalid_json',
      message: 'Request body must be valid UTF-8 JSON.',
    );
  }
}

/// Requires a specific HTTP method on an authentication endpoint.
void requireMethod(String actual, String expected) {
  if (actual.toUpperCase() != expected) {
    throw ApiException(
      statusCode: HttpStatus.methodNotAllowed,
      code: 'method_not_allowed',
      message: 'Only $expected is supported for this endpoint.',
    );
  }
}
