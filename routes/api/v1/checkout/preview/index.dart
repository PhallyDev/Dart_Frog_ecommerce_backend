import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/commerce/checkout_service.dart';
import 'package:shop_ease_ecommerce/src/commerce/request_validation.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

Future<Response> onRequest(RequestContext context) async {
  requireMethod(context.request.method.value, 'POST');
  final body = await readJsonObject(context);
  requireOnlyFields(body, const {'addressId', 'shippingMethodCode'});
  final addressId = body['addressId'];
  final shippingCode = body['shippingMethodCode'];
  if (addressId is! String || shippingCode is! String) {
    throw const ApiException(
      statusCode: 400,
      code: 'invalid_checkout',
      message: 'addressId and shippingMethodCode are required strings.',
    );
  }
  final quote = await context.read<CheckoutService>().preview(
    context.read<AuthPrincipal>().userId,
    addressId: addressId,
    shippingMethodCode: shippingCode,
  );
  return Response.json(body: {'checkout': quote});
}
