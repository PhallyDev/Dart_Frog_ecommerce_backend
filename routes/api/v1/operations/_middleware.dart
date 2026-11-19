import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/orders/operations_middleware.dart';
import 'package:shop_ease_ecommerce/src/orders/order_service_provider.dart';

Handler middleware(Handler handler) {
  return provideOrderServices(requireOrderOperationsToken(handler));
}
