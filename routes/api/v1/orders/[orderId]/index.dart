import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/commerce/request_validation.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/orders/order_service.dart';

Future<Response> onRequest(
  RequestContext context,
  String orderId,
) async {
  final id = parseObjectId(orderId, resource: 'order');
  final service = context.read<OrderService>();
  final userId = context.read<AuthPrincipal>().userId;
  final method = context.request.method.value.toUpperCase();
  if (method == 'GET') {
    return Response.json(body: await service.get(userId, id));
  }
  if (method == 'DELETE') {
    return Response.json(body: await service.cancel(userId, id));
  }
  throw const ApiException(
    statusCode: 405,
    code: 'method_not_allowed',
    message: 'Only GET and DELETE are supported for this endpoint.',
  );
}
