import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_service.dart';

Future<Response> onRequest(RequestContext context) async {
  requireMethod(context.request.method.value, 'POST');
  final body = await readJsonObject(context);
  final result = await context.read<AuthService>().signUp(body);
  return Response.json(statusCode: HttpStatus.created, body: result);
}
