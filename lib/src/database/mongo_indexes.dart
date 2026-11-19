import 'package:mongo_dart/mongo_dart.dart';

import 'package:shop_ease_ecommerce/src/database/collection_names.dart';

/// Declarative MongoDB index options for one collection.
class MongoIndexDefinition {
  /// Creates one named index definition.
  const MongoIndexDefinition({
    required this.collection,
    required this.keys,
    required this.name,
    this.unique = false,
    this.sparse = false,
  });

  /// Collection receiving this index.
  final String collection;

  /// Ordered MongoDB index key specification.
  final Map<String, Object> keys;

  /// Whether duplicate key values are rejected.
  final bool unique;

  /// Whether documents without indexed fields are excluded.
  final bool sparse;

  /// Stable MongoDB index name.
  final String name;
}

/// Index definitions applied during database initialization.
abstract final class MongoIndexes {
  /// Indexes supporting uniqueness and common ecommerce queries.
  static const definitions = <MongoIndexDefinition>[
    MongoIndexDefinition(
      collection: CollectionNames.users,
      keys: {'email': 1},
      unique: true,
      name: 'users_email_unique',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.userSessions,
      keys: {'userId': 1, 'revokedAt': 1, 'expiresAt': 1},
      name: 'user_sessions_user_revoked_expiry',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.categories,
      keys: {'slug': 1},
      unique: true,
      name: 'categories_slug_unique',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.products,
      keys: {'slug': 1},
      unique: true,
      name: 'products_slug_unique',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.products,
      keys: {'categoryId': 1, 'isActive': 1, 'priceMinor': 1},
      name: 'products_category_active_price',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.products,
      keys: {'name': 'text', 'description': 'text'},
      name: 'products_name_description_text',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.reviews,
      keys: {'productId': 1, 'userId': 1},
      unique: true,
      name: 'reviews_product_user_unique',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.reviews,
      keys: {'productId': 1, 'createdAt': -1},
      name: 'reviews_product_created',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.carts,
      keys: {'userId': 1},
      unique: true,
      name: 'carts_user_unique',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.coupons,
      keys: {'code': 1},
      unique: true,
      name: 'coupons_code_unique',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.addresses,
      keys: {'userId': 1, 'isDefault': -1},
      name: 'addresses_user_default',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.shippingMethods,
      keys: {'code': 1},
      unique: true,
      name: 'shipping_methods_code_unique',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.orders,
      keys: {'orderNumber': 1},
      unique: true,
      name: 'orders_order_number_unique',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.orders,
      keys: {'userId': 1, 'idempotencyKey': 1},
      unique: true,
      name: 'orders_user_idempotency_unique',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.orders,
      keys: {'userId': 1, 'createdAt': -1},
      name: 'orders_user_created',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.orders,
      keys: {'status': 1, 'createdAt': -1},
      name: 'orders_status_created',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.orderTrackingEvents,
      keys: {'orderId': 1, 'createdAt': 1},
      name: 'tracking_order_created',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.payments,
      keys: {'orderId': 1},
      unique: true,
      name: 'payments_order_unique',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.payments,
      keys: {'bakongTransactionHash': 1},
      unique: true,
      sparse: true,
      name: 'payments_bakong_transaction_unique',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.payments,
      keys: {'md5': 1},
      unique: true,
      name: 'payments_md5_unique',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.payments,
      keys: {'userId': 1, 'createdAt': -1},
      name: 'payments_user_created',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.wishlists,
      keys: {'userId': 1, 'productId': 1},
      unique: true,
      name: 'wishlists_user_product_unique',
    ),
    MongoIndexDefinition(
      collection: CollectionNames.userSettings,
      keys: {'userId': 1},
      unique: true,
      name: 'user_settings_user_unique',
    ),
  ];

  /// Creates each configured index, failing explicitly on database errors.
  static Future<void> ensureCreated(Db database) async {
    for (final definition in definitions) {
      await database.createIndex(
        definition.collection,
        keys: definition.keys,
        unique: definition.unique,
        sparse: definition.sparse,
        name: definition.name,
      );
    }
  }
}
