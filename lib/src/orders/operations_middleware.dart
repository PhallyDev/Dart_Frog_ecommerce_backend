import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/config/app_config.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/security/constant_time.dart';

/// Allows trusted order operations only when a server token is configured.
Handler requireOrderOperationsToken(Handler handler) {
  return (context) {
    final token = context.read<AppConfig>().orderOperationsToken;
    if (token == null) {
      throw const ApiException(
        statusCode: 503,
        code: 'order_operations_not_configured',
        message: 'Order operations are not configured on this server.',
      );
    }
    final authorization = context.request.headers['authorization'] ?? '';
    const prefix = 'Bearer ';
    if (!authorization.startsWith(prefix) ||
        !constantTimeEquals(authorization.substring(prefix.length), token)) {
      throw const ApiException(
        statusCode: 401,
        code: 'unauthorized',
        message: 'A valid order-operations token is required.',
      );
    }
    return handler(context);
  };
}
