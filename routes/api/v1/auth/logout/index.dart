import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/domain/entities/auth_identity.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_request.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_service.dart';

Future<Response> onRequest(RequestContext context) async {
  requireMethod(context.request.method.value, 'POST');
  await context.read<AuthService>().logout(context.read<AuthIdentity>());
  return Response(statusCode: HttpStatus.noContent);
}
