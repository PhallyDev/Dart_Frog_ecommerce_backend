import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/commerce/address_service.dart';
import 'package:shop_ease_ecommerce/src/http/query_parameters.dart';

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method.value.toUpperCase();
  final service = context.read<AddressService>();
  final userId = context.read<AuthPrincipal>().userId;
  if (method == 'GET') {
    final parameters = singleQueryParameters(
      context.request.uri.queryParametersAll,
    );
    return Response.json(body: await service.list(userId, parameters));
  }
  if (method == 'POST') {
    final body = await readJsonObject(context);
    final address = await service.create(userId, body);
    return Response.json(statusCode: 201, body: {'address': address});
  }

  requireMethod(method, 'GET or POST');
  throw StateError('Unreachable method dispatch.');
}
