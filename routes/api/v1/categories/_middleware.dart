import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/catalog/catalog_service.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database_provider.dart';

Handler middleware(Handler handler) {
  return (context) => handler(
    context.provide<CatalogService>(
      () => CatalogService.fromProvider(
        () => MongoDatabaseProvider.instance,
      ),
    ),
  );
}
