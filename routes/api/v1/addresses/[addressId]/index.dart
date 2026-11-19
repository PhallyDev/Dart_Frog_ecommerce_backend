import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/commerce/address_service.dart';
import 'package:shop_ease_ecommerce/src/commerce/request_validation.dart';

Future<Response> onRequest(
  RequestContext context,
  String addressId,
) async {
  final method = context.request.method.value.toUpperCase();
  final id = parseObjectId(addressId, resource: 'address');
  final userId = context.read<AuthPrincipal>().userId;
  final service = context.read<AddressService>();
  if (method == 'PUT') {
    final body = await readJsonObject(context);
    final address = await service.update(userId, id, body);
    return Response.json(body: {'address': address});
  }
  if (method == 'DELETE') {
    await service.delete(userId, id);
    return Response(statusCode: 204);
  }
  requireMethod(method, 'PUT or DELETE');
  throw StateError('Unreachable method dispatch.');
}
