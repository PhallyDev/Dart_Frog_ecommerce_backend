import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/account/account_service.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method.value.toUpperCase();
  final service = context.read<AccountService>();
  final userId = context.read<AuthPrincipal>().userId;
  if (method == 'GET') {
    return Response.json(body: await service.getSettings(userId));
  }
  if (method == 'PUT') {
    final body = await readJsonObject(context);
    return Response.json(body: await service.updateSettings(userId, body));
  }
  requireMethod(method, 'GET or PUT');
  throw StateError('Unreachable method dispatch.');
}
