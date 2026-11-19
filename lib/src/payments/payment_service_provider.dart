import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/config/app_config.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database_provider.dart';
import 'package:shop_ease_ecommerce/src/orders/order_repository.dart';
import 'package:shop_ease_ecommerce/src/payments/bakong_api_client.dart';
import 'package:shop_ease_ecommerce/src/payments/payment_repository.dart';
import 'package:shop_ease_ecommerce/src/payments/payment_service.dart';

Handler providePaymentServices(Handler handler) {
  return (context) {
    final config = AppConfig.load();
    final bakongClient = BakongApiClient(config);
    final service = PaymentService(
      () async => MongoPaymentRepository(
        await MongoDatabaseProvider.instance,
      ),
      () async => MongoOrderRepository(
        await MongoDatabaseProvider.instance,
      ),
      config,
      bakongClient,
    );
    return handler(
      context
          .provide<AppConfig>(() => config)
          .provide<PaymentService>(() => service),
    );
  };
}
