import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_middleware.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_service_provider.dart';
import 'package:shop_ease_ecommerce/src/payments/payment_service_provider.dart';

Handler middleware(Handler handler) {
  final authenticatedHandler = requireAuthenticatedUser(handler);
  return provideAuthService(
    (context) => providePaymentServices(authenticatedHandler)(context),
  );
}
