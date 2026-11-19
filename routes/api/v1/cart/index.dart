import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/commerce/cart_service.dart';
import 'package:shop_ease_ecommerce/src/http/query_parameters.dart';

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method.value.toUpperCase();
  final service = context.read<CartService>();
  final userId = context.read<AuthPrincipal>().userId;
  if (method == 'GET') {
    requireGet(method);
    return Response.json(body: {'cart': await service.getCart(userId)});
  }
  if (method == 'DELETE') {
    return Response.json(body: {'cart': await service.clearCart(userId)});
  }
  requireMethod(method, 'GET or DELETE');
  throw StateError('Unreachable method dispatch.');
}
