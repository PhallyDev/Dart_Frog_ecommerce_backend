import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/database/collection_names.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

/// Lazily supplies a persistence implementation to commerce services.
typedef ShopRepositoryProvider = Future<ShopRepository> Function();

/// MongoDB operations used by shopping-cart and wishlist services.
abstract interface class ShopRepository {
  /// Finds one user's cart document.
  Future<Map<String, dynamic>?> findCart(ObjectId userId);

  /// Finds a product by ID, including inactive products.
  Future<Map<String, dynamic>?> findProduct(ObjectId productId);

  /// Finds products by ID in one database query.
  Future<List<Map<String, dynamic>>> findProducts(Set<ObjectId> productIds);

  /// Finds a normalized coupon code.
  Future<Map<String, dynamic>?> findCoupon(String code);

  /// Finds an address owned by the authenticated user.
  Future<Map<String, dynamic>?> findAddress(ObjectId userId, ObjectId id);

  /// Lists user-owned addresses.
  Future<List<Map<String, dynamic>>> findAddresses(
    ObjectId userId, {
    required int skip,
    required int limit,
  });

  /// Counts addresses belonging to a user.
  Future<int> countAddresses(ObjectId userId);

  /// Creates an address document.
  Future<ObjectId> createAddress(
    ObjectId userId,
    Map<String, Object?> address,
    DateTime now,
  );

  /// Updates a user-owned address.
  Future<bool> updateAddress(
    ObjectId userId,
    ObjectId id,
    Map<String, Object?> address,
    DateTime now,
  );

  /// Deletes a user-owned address.
  Future<bool> deleteAddress(ObjectId userId, ObjectId id);

  /// Sets one user-owned address as default.
  Future<bool> setDefaultAddress(ObjectId userId, ObjectId id, DateTime now);

  /// Lists active shipping methods.
  Future<List<Map<String, dynamic>>> findShippingMethods({
    required int skip,
    required int limit,
  });

  /// Counts active shipping methods.
  Future<int> countShippingMethods();

  /// Finds one active shipping method by code.
  Future<Map<String, dynamic>?> findShippingMethod(String code);

  /// Finds one order by the requesting user's idempotency key.
  Future<Map<String, dynamic>?> findOrderByIdempotencyKey(
    ObjectId userId,
    String key,
  );

  /// Atomically reserves stock while confirming the reviewed product price.
  Future<bool> reserveStock(
    ObjectId productId,
    int quantity,
    int priceMinor,
    String currency,
    DateTime now,
  );

  /// Returns reserved stock when order creation is compensated.
  Future<void> releaseStock(ObjectId productId, int quantity);

  /// Atomically reserves one eligible coupon use.
  Future<bool> reserveCouponUse(
    String code,
    DateTime now,
    Map<String, Object?> expectedTerms,
  );

  /// Returns a coupon use when order creation is compensated.
  Future<void> releaseCouponUse(String code);

  /// Inserts an order after inventory and coupon reservations succeed.
  Future<void> insertOrder(Map<String, Object?> order);

  /// Removes the user's cart after a successful order.
  Future<void> clearCartForCheckout(
    ObjectId userId,
    List<Map<String, Object?>> expectedItems,
    String? expectedCouponCode,
    DateTime now,
  );

  /// Atomically increments or inserts a cart item without exceeding stock.
  Future<void> addCartItem(
    ObjectId userId,
    ObjectId productId,
    int quantity,
    int stock,
    DateTime now,
  );

  /// Replaces the quantity for an item in the user's cart.
  Future<void> setCartItemQuantity(
    ObjectId userId,
    ObjectId productId,
    int quantity,
    DateTime now,
  );

  /// Removes an item from the user's cart.
  Future<void> removeCartItem(
    ObjectId userId,
    ObjectId productId,
    DateTime now,
  );

  /// Empties the cart and removes its applied coupon.
  Future<void> clearCart(ObjectId userId, DateTime now);

  /// Stores the coupon selected for the user's cart.
  Future<void> setCartCoupon(ObjectId userId, String code, DateTime now);

  /// Removes the coupon selected for the user's cart.
  Future<void> removeCartCoupon(ObjectId userId, DateTime now);

  /// Retrieves one page of wishlist records for a user.
  Future<List<Map<String, dynamic>>> findWishlist(
    ObjectId userId, {
    required int skip,
    required int limit,
  });

  /// Counts wishlist records for a user.
  Future<int> countWishlist(ObjectId userId);

  /// Idempotently adds a product to a user's wishlist.
  Future<bool> addWishlistItem(ObjectId userId, ObjectId productId);

  /// Removes one product from a user's wishlist.
  Future<void> removeWishlistItem(ObjectId userId, ObjectId productId);
}

/// MongoDB-backed cart and wishlist persistence.
class MongoShopRepository implements ShopRepository {
  /// Creates a repository using the shared database connection.
  MongoShopRepository(this._database);

  final MongoDatabase _database;

  DbCollection get _carts => _database.collection(CollectionNames.carts);
  DbCollection get _coupons => _database.collection(CollectionNames.coupons);
  DbCollection get _addresses =>
      _database.collection(CollectionNames.addresses);
  DbCollection get _orders => _database.collection(CollectionNames.orders);
  DbCollection get _products => _database.collection(CollectionNames.products);
  DbCollection get _shippingMethods =>
      _database.collection(CollectionNames.shippingMethods);
  DbCollection get _wishlists =>
      _database.collection(CollectionNames.wishlists);

  @override
  Future<Map<String, dynamic>?> findCart(ObjectId userId) =>
      _carts.findOne(where.eq('userId', userId));

  @override
  Future<Map<String, dynamic>?> findProduct(ObjectId productId) =>
      _products.findOne(where.id(productId));

  @override
  Future<List<Map<String, dynamic>>> findProducts(Set<ObjectId> productIds) {
    if (productIds.isEmpty) return Future.value(const []);
    return _products.find({
      '_id': {r'$in': productIds.toList()},
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> findCoupon(String code) =>
      _coupons.findOne(where.eq('code', code));

  @override
  Future<Map<String, dynamic>?> findAddress(ObjectId userId, ObjectId id) =>
      _addresses.findOne(where.id(id).eq('userId', userId));

  @override
  Future<List<Map<String, dynamic>>> findAddresses(
    ObjectId userId, {
    required int skip,
    required int limit,
  }) => _addresses
      .find(
        where
            .eq('userId', userId)
            .sortBy('isDefault', descending: true)
            .sortBy('createdAt', descending: true)
            .skip(skip)
            .limit(limit),
      )
      .toList();

  @override
  Future<int> countAddresses(ObjectId userId) =>
      _addresses.count(where.eq('userId', userId));

  @override
  Future<ObjectId> createAddress(
    ObjectId userId,
    Map<String, Object?> address,
    DateTime now,
  ) async {
    final id = ObjectId();
    await _addresses.insertOne({
      '_id': id,
      'userId': userId,
      ...address,
      'isDefault': address['isDefault'] == true,
      'createdAt': now,
      'updatedAt': now,
    });
    if (address['isDefault'] == true) {
      await _addresses.updateMany(
        {
          'userId': userId,
          'isDefault': true,
          '_id': {r'$ne': id},
        },
        modify.set('isDefault', false).set('updatedAt', now),
      );
    }
    return id;
  }

  @override
  Future<bool> updateAddress(
    ObjectId userId,
    ObjectId id,
    Map<String, Object?> address,
    DateTime now,
  ) async {
    final result = await _addresses.updateOne(
      where.id(id).eq('userId', userId),
      modify
          .set('recipientName', address['recipientName'])
          .set('line1', address['line1'])
          .set('line2', address['line2'])
          .set('city', address['city'])
          .set('region', address['region'])
          .set('postalCode', address['postalCode'])
          .set('countryCode', address['countryCode'])
          .set('phone', address['phone'])
          .set('isDefault', address['isDefault'])
          .set('updatedAt', now),
    );
    if (result.nMatched == 1 && address['isDefault'] == true) {
      await _addresses.updateMany(
        {
          'userId': userId,
          'isDefault': true,
          '_id': {r'$ne': id},
        },
        modify.set('isDefault', false).set('updatedAt', now),
      );
    }
    return result.nMatched == 1;
  }

  @override
  Future<bool> deleteAddress(ObjectId userId, ObjectId id) async {
    final result = await _addresses.remove(
      where.id(id).eq('userId', userId),
    );
    return (result['n'] as num?)?.toInt() != 0;
  }

  @override
  Future<bool> setDefaultAddress(
    ObjectId userId,
    ObjectId id,
    DateTime now,
  ) async {
    final address = await findAddress(userId, id);
    if (address == null) return false;
    final result = await _addresses.updateOne(
      where.id(id).eq('userId', userId),
      modify.set('isDefault', true).set('updatedAt', now),
    );
    if (result.nMatched == 1) {
      await _addresses.updateMany(
        {
          'userId': userId,
          'isDefault': true,
          '_id': {r'$ne': id},
        },
        modify.set('isDefault', false).set('updatedAt', now),
      );
      return true;
    }
    return false;
  }

  @override
  Future<List<Map<String, dynamic>>> findShippingMethods({
    required int skip,
    required int limit,
  }) => _shippingMethods
      .find(
        where
            .eq('isActive', true)
            .sortBy('priceMinor')
            .sortBy('code')
            .skip(skip)
            .limit(limit),
      )
      .toList();

  @override
  Future<int> countShippingMethods() =>
      _shippingMethods.count(where.eq('isActive', true));

  @override
  Future<Map<String, dynamic>?> findShippingMethod(String code) =>
      _shippingMethods.findOne(where.eq('code', code).eq('isActive', true));

  @override
  Future<Map<String, dynamic>?> findOrderByIdempotencyKey(
    ObjectId userId,
    String key,
  ) => _orders.findOne(
    where.eq('userId', userId).eq('idempotencyKey', key),
  );

  @override
  Future<bool> reserveStock(
    ObjectId productId,
    int quantity,
    int priceMinor,
    String currency,
    DateTime now,
  ) async {
    final result = await _products.updateOne(
      where
          .id(productId)
          .eq('isActive', true)
          .eq('priceMinor', priceMinor)
          .eq('currency', currency)
          .gte('stock', quantity),
      modify.inc('stock', -quantity).set('updatedAt', now),
    );
    return result.nMatched == 1;
  }

  @override
  Future<void> releaseStock(ObjectId productId, int quantity) async {
    await _products.updateOne(
      where.id(productId),
      modify.inc('stock', quantity).set('updatedAt', DateTime.now().toUtc()),
    );
  }

  @override
  Future<bool> reserveCouponUse(
    String code,
    DateTime now,
    Map<String, Object?> expectedTerms,
  ) async {
    final selector = <String, dynamic>{
      'code': code,
      'isActive': true,
      'usageCount': {r'$gte': 0},
      ...{
        for (final field in const [
          'kind',
          'value',
          'currency',
          'minimumSubtotalMinor',
          'maximumDiscountMinor',
          'usageLimit',
          'startsAt',
          'expiresAt',
        ])
          field: expectedTerms.containsKey(field)
              ? expectedTerms[field]
              : {r'$exists': false},
      },
      r'$and': [
        {
          r'$or': [
            {
              'startsAt': {r'$exists': false},
            },
            {
              'startsAt': {r'$lte': now},
            },
          ],
        },
        {
          r'$or': [
            {
              'expiresAt': {r'$exists': false},
            },
            {
              'expiresAt': {r'$gt': now},
            },
          ],
        },
        {
          r'$or': [
            {
              'usageLimit': {r'$exists': false},
            },
            {
              r'$expr': {
                r'$lt': [r'$usageCount', r'$usageLimit'],
              },
            },
          ],
        },
      ],
    };
    final result = await _coupons.updateOne(
      selector,
      {
        r'$inc': {'usageCount': 1},
        r'$set': {'updatedAt': now},
      },
    );
    return result.nMatched == 1;
  }

  @override
  Future<void> releaseCouponUse(String code) async {
    await _coupons.updateOne(
      where.eq('code', code).gt('usageCount', 0),
      modify.inc('usageCount', -1).set('updatedAt', DateTime.now().toUtc()),
    );
  }

  @override
  Future<void> insertOrder(Map<String, Object?> order) async {
    await _orders.insertOne(order);
  }

  @override
  Future<void> clearCartForCheckout(
    ObjectId userId,
    List<Map<String, Object?>> expectedItems,
    String? expectedCouponCode,
    DateTime now,
  ) async {
    final selector = <String, Object>{
      'userId': userId,
      'items': expectedItems,
      if (expectedCouponCode != null) 'couponCode': expectedCouponCode,
      if (expectedCouponCode == null) 'couponCode': {r'$exists': false},
    };
    await _carts.updateOne(
      selector,
      {
        r'$set': {
          'items': <Map<String, Object>>[],
          'updatedAt': now,
        },
        r'$unset': {'couponCode': ''},
      },
    );
  }

  Future<void> _ensureCart(ObjectId userId, DateTime now) async {
    try {
      await _carts.updateOne(
        {'userId': userId},
        {
          r'$setOnInsert': {
            'userId': userId,
            'items': <Map<String, Object>>[],
            'updatedAt': now,
          },
        },
        upsert: true,
      );
      // mongo_dart represents duplicate-key server failures as MongoDartError.
      // ignore: avoid_catching_errors
    } on MongoDartError catch (error) {
      if (error.mongoCode != 11000 && !error.message.contains('E11000')) {
        rethrow;
      }
    }
  }

  @override
  Future<void> addCartItem(
    ObjectId userId,
    ObjectId productId,
    int quantity,
    int stock,
    DateTime now,
  ) async {
    await _ensureCart(userId, now);
    for (var attempt = 0; attempt < 3; attempt++) {
      final result = await _carts.updateOne(
        {
          'userId': userId,
          'items': {
            r'$elemMatch': {
              'productId': productId,
              'quantity': {r'$lte': stock - quantity},
            },
          },
        },
        {
          r'$inc': {r'items.$.quantity': quantity},
          r'$set': {'updatedAt': now},
        },
      );
      if (result.nMatched == 1) return;

      final cart = await findCart(userId);
      final items = cart?['items'];
      if (items is List) {
        for (final item in items) {
          if (item is Map && item['productId'] == productId) {
            final currentQuantity = item['quantity'];
            if (currentQuantity is! num || currentQuantity + quantity > stock) {
              throw const ApiException(
                statusCode: 409,
                code: 'insufficient_stock',
                message: 'Requested quantity exceeds available stock.',
              );
            }
            break;
          }
        }
      }

      final inserted = await _carts.updateOne(
        {
          'userId': userId,
          'items.productId': {r'$ne': productId},
        },
        {
          r'$push': {
            'items': {
              'productId': productId,
              'quantity': quantity,
              'addedAt': now,
            },
          },
          r'$set': {'updatedAt': now},
        },
      );
      if (inserted.nMatched == 1) return;
    }
    throw StateError('Concurrent cart update could not be completed.');
  }

  @override
  Future<void> setCartItemQuantity(
    ObjectId userId,
    ObjectId productId,
    int quantity,
    DateTime now,
  ) async {
    final result = await _carts.updateOne(
      {
        'userId': userId,
        'items': {
          r'$elemMatch': {
            'productId': productId,
            'quantity': {r'$gte': 1},
          },
        },
      },
      {
        r'$set': {
          r'items.$.quantity': quantity,
          'updatedAt': now,
        },
      },
    );
    if (result.nMatched != 1) {
      throw StateError('Cart item disappeared during quantity update.');
    }
  }

  @override
  Future<void> removeCartItem(
    ObjectId userId,
    ObjectId productId,
    DateTime now,
  ) async {
    await _carts.updateOne(
      {'userId': userId},
      {
        r'$pull': {
          'items': {'productId': productId},
        },
        r'$set': {'updatedAt': now},
      },
    );
  }

  @override
  Future<void> clearCart(ObjectId userId, DateTime now) async {
    await _ensureCart(userId, now);
    await _carts.updateOne(
      {'userId': userId},
      {
        r'$set': {
          'items': <Map<String, Object>>[],
          'updatedAt': now,
        },
        r'$unset': {'couponCode': ''},
      },
    );
  }

  @override
  Future<void> setCartCoupon(
    ObjectId userId,
    String code,
    DateTime now,
  ) async {
    await _ensureCart(userId, now);
    await _carts.updateOne(
      {'userId': userId},
      {
        r'$set': {
          'couponCode': code,
          'updatedAt': now,
        },
      },
    );
  }

  @override
  Future<void> removeCartCoupon(ObjectId userId, DateTime now) async {
    await _carts.updateOne(
      {'userId': userId},
      {
        r'$unset': {'couponCode': ''},
        r'$set': {'updatedAt': now},
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> findWishlist(
    ObjectId userId, {
    required int skip,
    required int limit,
  }) => _wishlists
      .find(
        where
            .eq('userId', userId)
            .sortBy('addedAt', descending: true)
            .skip(skip)
            .limit(limit),
      )
      .toList();

  @override
  Future<int> countWishlist(ObjectId userId) =>
      _wishlists.count(where.eq('userId', userId));

  @override
  Future<bool> addWishlistItem(ObjectId userId, ObjectId productId) async {
    try {
      final result = await _wishlists.updateOne(
        {'userId': userId, 'productId': productId},
        {
          r'$setOnInsert': {
            'userId': userId,
            'productId': productId,
            'addedAt': DateTime.now().toUtc(),
          },
        },
        upsert: true,
      );
      return result.nUpserted == 1;
      // mongo_dart represents duplicate-key server failures as MongoDartError.
      // ignore: avoid_catching_errors
    } on MongoDartError catch (error) {
      if (error.mongoCode != 11000 && !error.message.contains('E11000')) {
        rethrow;
      }
      return false;
    }
  }

  @override
  Future<void> removeWishlistItem(ObjectId userId, ObjectId productId) async {
    await _wishlists.remove(
      where.eq('userId', userId).eq('productId', productId),
    );
  }
}
