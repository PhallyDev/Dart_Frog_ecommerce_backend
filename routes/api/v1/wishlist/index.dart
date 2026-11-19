import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/commerce/request_validation.dart';
import 'package:shop_ease_ecommerce/src/commerce/wishlist_service.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/http/query_parameters.dart';

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method.value.toUpperCase();
  final service = context.read<WishlistService>();
  final userId = context.read<AuthPrincipal>().userId;
  if (method == 'GET') {
    final parameters = singleQueryParameters(
      context.request.uri.queryParametersAll,
    );
    return Response.json(
      body: await service.list(userId, parameters),
    );
  }
  if (method == 'POST') {
    final body = await readJsonObject(context);
    requireOnlyFields(body, const {'productId'});
    final productId = body['productId'];
    if (productId is! String) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_product_id',
        message: 'productId must be a valid product ID string.',
      );
    }
    final created = await service.add(userId, parseProductId(productId));
    return Response.json(
      statusCode: created ? 201 : 200,
      body: {'message': 'Product added to wishlist.'},
    );
  }
  throw const ApiException(
    statusCode: 405,
    code: 'method_not_allowed',
    message: 'Only GET or POST is supported for this endpoint.',
  );
}
