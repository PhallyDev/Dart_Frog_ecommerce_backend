import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/domain/entities/auth_identity.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_principal.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_service.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

/// Requires a valid Bearer token and provides its authenticated principal.
Handler requireAuthenticatedUser(Handler handler) {
  return (context) async {
    final authorization = context.request.headers['authorization'];
    if (authorization == null) {
      throw const ApiException(
        statusCode: 401,
        code: 'unauthorized',
        message: 'Authentication is required or the session has expired.',
      );
    }
    final identity = await context.read<AuthService>().authenticate(
      authorization,
    );
    final principal = AuthPrincipal(
      userId: ObjectId.fromHexString(identity.userId),
      sessionId: ObjectId.fromHexString(identity.sessionId),
    );
    return handler(
      context
          .provide<AuthIdentity>(() => identity)
          .provide<AuthPrincipal>(() => principal),
    );
  };
}
