import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/commerce/request_validation.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/payments/payment_service.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method.value.toUpperCase() != 'POST') {
    throw const ApiException(
      statusCode: HttpStatus.methodNotAllowed,
      code: 'method_not_allowed',
      message: 'Only POST is supported for this endpoint.',
    );
  }
  final body = await readJsonObject(context);
  requireOnlyFields(body, const {'orderId'});
  final orderId = body['orderId'];
  if (orderId is! String) {
    throw const ApiException(
      statusCode: HttpStatus.badRequest,
      code: 'invalid_payment',
      message: 'orderId is required.',
    );
  }
  final id = parseObjectId(orderId, resource: 'order');
  final result = await context.read<PaymentService>().create(
    context.read<AuthPrincipal>().userId,
    id,
  );
  return Response.json(statusCode: HttpStatus.created, body: result);
}
