import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_rate_limiter.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_service_provider.dart';

Handler middleware(Handler handler) {
  return provideAuthService((context) {
    final remoteAddress = context.request.connectionInfo.remoteAddress.address;
    final segments = context.request.uri.pathSegments;
    final endpoint = segments.length > 3 ? segments[3] : 'auth';
    AuthRateLimiter.enforce(remoteAddress, endpoint);
    return handler(context);
  });
}
