import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_middleware.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_service_provider.dart';
import 'package:shop_ease_ecommerce/src/commerce/shop_repository.dart';
import 'package:shop_ease_ecommerce/src/commerce/wishlist_service.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database_provider.dart';

Handler middleware(Handler handler) {
  final authenticatedHandler = requireAuthenticatedUser(handler);
  return provideAuthService((context) {
    final service = WishlistService(
      () async => MongoShopRepository(await MongoDatabaseProvider.instance),
    );
    return authenticatedHandler(
      context.provide<WishlistService>(() => service),
    );
  });
}
