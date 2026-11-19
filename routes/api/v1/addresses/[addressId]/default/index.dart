import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/commerce/address_service.dart';
import 'package:shop_ease_ecommerce/src/commerce/request_validation.dart';

Future<Response> onRequest(
  RequestContext context,
  String addressId,
) async {
  requireMethod(context.request.method.value, 'PUT');
  await context.read<AddressService>().setDefault(
    context.read<AuthPrincipal>().userId,
    parseObjectId(addressId, resource: 'address'),
  );
  return Response.json(body: {'message': 'Default address updated.'});
}
