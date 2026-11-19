import 'package:shop_ease_ecommerce/src/database/collection_names.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_indexes.dart';
import 'package:test/test.dart';

void main() {
  test('defines indexes for every ShopEase collection.', () {
    final indexedCollections = MongoIndexes.definitions
        .map((definition) => definition.collection)
        .toSet();

    expect(
      indexedCollections,
      containsAll({
        CollectionNames.users,
        CollectionNames.categories,
        CollectionNames.products,
        CollectionNames.reviews,
        CollectionNames.carts,
        CollectionNames.coupons,
        CollectionNames.addresses,
        CollectionNames.shippingMethods,
        CollectionNames.orders,
        CollectionNames.orderTrackingEvents,
        CollectionNames.wishlists,
        CollectionNames.userSettings,
      }),
    );
  });

  test(
    'declares unique constraints for identity and deduplication fields.',
    () {
      final uniqueDefinitions = MongoIndexes.definitions
          .where((definition) => definition.unique)
          .map((definition) => definition.name)
          .toSet();

      expect(
        uniqueDefinitions,
        containsAll({
          'users_email_unique',
          'orders_user_idempotency_unique',
          'wishlists_user_product_unique',
        }),
      );
    },
  );
}
