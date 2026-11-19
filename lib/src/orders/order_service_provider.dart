import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/config/app_config.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database_provider.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/orders/order_repository.dart';
import 'package:shop_ease_ecommerce/src/orders/order_service.dart';

/// Provides order services using the shared MongoDB connection.
Handler provideOrderServices(Handler handler) {
  return (context) {
    final AppConfig config;
    try {
      config = AppConfig.load();
    } on FormatException {
      throw const ApiException(
        statusCode: 503,
        code: 'order_service_not_configured',
        message: 'Order services are not configured.',
      );
    }
    Future<OrderRepository> repositoryProvider() async =>
        MongoOrderRepository(await MongoDatabaseProvider.instance);
    final orderService = OrderService(repositoryProvider);
    return handler(
      context
          .provide<AppConfig>(() => config)
          .provide<OrderService>(() => orderService),
    );
  };
}
