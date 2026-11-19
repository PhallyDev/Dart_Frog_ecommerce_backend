import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/commerce/request_validation.dart';
import 'package:shop_ease_ecommerce/src/commerce/wishlist_service.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

Future<Response> onRequest(
  RequestContext context,
  String productId,
) async {
  if (context.request.method.value.toUpperCase() != 'DELETE') {
    throw const ApiException(
      statusCode: 405,
      code: 'method_not_allowed',
      message: 'Only DELETE is supported for this endpoint.',
    );
  }
  await context.read<WishlistService>().remove(
    context.read<AuthPrincipal>().userId,
    parseProductId(productId),
  );
  return Response(statusCode: 204);
}
