import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

/// Parses and validates a MongoDB object identifier from a route/body.
ObjectId parseObjectId(String value, {String resource = 'resource'}) {
  if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value)) {
    throw ApiException(
      statusCode: HttpStatus.badRequest,
      code: 'invalid_id',
      message: 'The $resource ID is invalid.',
    );
  }
  return ObjectId.fromHexString(value);
}

/// Parses and validates a MongoDB product identifier from a route/body.
ObjectId parseProductId(String value) =>
    parseObjectId(value, resource: 'product');

/// Rejects JSON object keys not supported by an endpoint.
void requireOnlyFields(
  Map<String, Object?> body,
  Set<String> supported,
) {
  final unknown = body.keys.toSet().difference(supported);
  if (unknown.isNotEmpty) {
    throw ApiException(
      statusCode: HttpStatus.badRequest,
      code: 'invalid_request',
      message: 'Unsupported request field: ${unknown.first}.',
    );
  }
}

/// Parses a bounded positive cart quantity.
int parseQuantity(Object? raw) {
  if (raw is! num || raw != raw.toInt() || raw < 1 || raw > 99) {
    throw const ApiException(
      statusCode: HttpStatus.badRequest,
      code: 'invalid_quantity',
      message: 'Quantity must be an integer between 1 and 99.',
    );
  }
  return raw.toInt();
}

/// Validates a coupon code before business-rule normalization.
String parseCouponCode(Object? raw) {
  if (raw is! String || raw.trim().isEmpty || raw.length > 64) {
    throw const ApiException(
      statusCode: HttpStatus.badRequest,
      code: 'invalid_coupon_code',
      message: 'A valid coupon code is required.',
    );
  }
  return raw;
}
