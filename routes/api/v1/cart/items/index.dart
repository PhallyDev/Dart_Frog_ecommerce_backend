import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/commerce/cart_service.dart';
import 'package:shop_ease_ecommerce/src/commerce/request_validation.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

Future<Response> onRequest(RequestContext context) async {
  requireMethod(context.request.method.value, 'POST');
  final body = await readJsonObject(context);
  requireOnlyFields(body, const {'productId', 'quantity'});
  final productId = body['productId'];
  if (productId is! String) {
    throw const ApiException(
      statusCode: 400,
      code: 'invalid_product_id',
      message: 'productId must be a valid product ID string.',
    );
  }
  final quantity = body.containsKey('quantity')
      ? parseQuantity(body['quantity'])
      : 1;
  final cart = await context.read<CartService>().addItem(
    context.read<AuthPrincipal>().userId,
    parseProductId(productId),
    quantity,
  );
  return Response.json(body: {'cart': cart});
}
