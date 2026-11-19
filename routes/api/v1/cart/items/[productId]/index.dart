import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/commerce/cart_service.dart';
import 'package:shop_ease_ecommerce/src/commerce/request_validation.dart';

Future<Response> onRequest(
  RequestContext context,
  String productId,
) async {
  final method = context.request.method.value.toUpperCase();
  final service = context.read<CartService>();
  final userId = context.read<AuthPrincipal>().userId;
  final id = parseProductId(productId);
  if (method == 'PATCH') {
    final body = await readJsonObject(context);
    requireOnlyFields(body, const {'quantity'});
    final quantity = parseQuantity(body['quantity']);
    final cart = await service.updateItemQuantity(userId, id, quantity);
    return Response.json(body: {'cart': cart});
  }
  if (method == 'DELETE') {
    return Response.json(
      body: {'cart': await service.removeItem(userId, id)},
    );
  }
  requireMethod(method, 'PATCH or DELETE');
  throw StateError('Unreachable method dispatch.');
}
