import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/commerce/cart_service.dart';
import 'package:shop_ease_ecommerce/src/commerce/request_validation.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method.value.toUpperCase();
  final service = context.read<CartService>();
  final userId = context.read<AuthPrincipal>().userId;
  if (method == 'POST') {
    final body = await readJsonObject(context);
    requireOnlyFields(body, const {'code'});
    final cart = await service.applyCoupon(
      userId,
      parseCouponCode(body['code']),
    );
    return Response.json(body: {'cart': cart});
  }
  if (method == 'DELETE') {
    return Response.json(
      body: {'cart': await service.removeCoupon(userId)},
    );
  }
  throw const ApiException(
    statusCode: 405,
    code: 'method_not_allowed',
    message: 'Only POST or DELETE is supported for this endpoint.',
  );
}
