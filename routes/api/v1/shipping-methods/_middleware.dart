import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/commerce/shipping_service.dart';
import 'package:shop_ease_ecommerce/src/commerce/shop_repository.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database_provider.dart';

Handler middleware(Handler handler) {
  return (context) => handler(
    context.provide<ShippingService>(
      () => ShippingService(
        () async => MongoShopRepository(await MongoDatabaseProvider.instance),
      ),
    ),
  );
}
