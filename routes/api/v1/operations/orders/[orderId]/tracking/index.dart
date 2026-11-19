import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/commerce/request_validation.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/orders/order_service.dart';

Future<Response> onRequest(
  RequestContext context,
  String orderId,
) async {
  if (context.request.method.value.toUpperCase() != 'POST') {
    throw const ApiException(
      statusCode: 405,
      code: 'method_not_allowed',
      message: 'Only POST is supported for this endpoint.',
    );
  }
  final body = await readJsonObject(context);
  requireOnlyFields(body, const {'status', 'message', 'location'});
  final status = body['status'];
  final message = body['message'];
  final location = body['location'];
  if (status is! String ||
      message is! String ||
      message.trim().isEmpty ||
      message.length > 500 ||
      (location != null && (location is! String || location.length > 200))) {
    throw const ApiException(
      statusCode: 400,
      code: 'invalid_tracking_event',
      message: 'Tracking status, message, or location is invalid.',
    );
  }
  final result = await context.read<OrderService>().updateTracking(
    orderId: parseObjectId(orderId, resource: 'order'),
    status: status,
    message: message,
    location: location is String ? location : null,
  );
  return Response.json(statusCode: 201, body: {'event': result});
}
