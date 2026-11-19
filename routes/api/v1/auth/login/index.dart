import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_service.dart';

Future<Response> onRequest(RequestContext context) async {
  requireMethod(context.request.method.value, 'POST');
  final body = await readJsonObject(context);
  final result = await context.read<AuthService>().login(body);
  final user = result['user']! as Map<String, Object?>;
  final data = {
    ...result,
    'user': {...user, 'name': user['displayName']},
  };
  return Response.json(
    body: {
      'success': true,
      'message': 'Login successful',
      'data': data,
      ...result,
    },
  );
}
