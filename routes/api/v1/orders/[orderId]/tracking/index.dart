import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/commerce/request_validation.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/orders/order_service.dart';

Future<Response> onRequest(
  RequestContext context,
  String orderId,
) async {
  if (context.request.method.value.toUpperCase() != 'GET') {
    throw const ApiException(
      statusCode: 405,
      code: 'method_not_allowed',
      message: 'Only GET is supported for this endpoint.',
    );
  }
  return Response.json(
    body: await context.read<OrderService>().tracking(
      context.read<AuthPrincipal>().userId,
      parseObjectId(orderId, resource: 'order'),
    ),
  );
}
