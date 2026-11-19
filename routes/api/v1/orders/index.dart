import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/http/query_parameters.dart';
import 'package:shop_ease_ecommerce/src/orders/order_service.dart';

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method.value.toUpperCase();
  if (method != 'GET') {
    throw const ApiException(
      statusCode: 405,
      code: 'method_not_allowed',
      message: 'Only GET is supported for this endpoint.',
    );
  }
  final parameters = singleQueryParameters(
    context.request.uri.queryParametersAll,
  );
  return Response.json(
    body: await context.read<OrderService>().list(
      context.read<AuthPrincipal>().userId,
      parameters,
    ),
  );
}
