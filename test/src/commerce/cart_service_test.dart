import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/commerce/cart_service.dart';
import 'package:shop_ease_ecommerce/src/commerce/checkout_service.dart';
import 'package:shop_ease_ecommerce/src/commerce/shop_repository.dart';
import 'package:shop_ease_ecommerce/src/commerce/wishlist_service.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:test/test.dart';

class _MemoryShopRepository extends Mock implements ShopRepository {
  Map<String, dynamic>? cart;
  final Map<ObjectId, Map<String, dynamic>> products = {};
  final Map<String, Map<String, dynamic>> coupons = {};
  final Map<ObjectId, DateTime> wishlist = {};
  final Map<ObjectId, Map<String, dynamic>> addresses = {};
  final Map<String, Map<String, dynamic>> shippingMethods = {};
  final Map<String, Map<String, dynamic>> orders = {};
  ObjectId? failReservationFor;
  bool failCouponReservation = false;

  @override
  Future<Map<String, dynamic>?> findCart(ObjectId userId) async => cart;

  @override
  Future<Map<String, dynamic>?> findProduct(ObjectId productId) async =>
      products[productId];

  @override
  Future<List<Map<String, dynamic>>> findProducts(
    Set<ObjectId> productIds,
  ) async => [
    for (final id in productIds)
      if (products[id] case final product?) product,
  ];

  @override
  Future<Map<String, dynamic>?> findCoupon(String code) async => coupons[code];

  @override
  Future<Map<String, dynamic>?> findAddress(
    ObjectId userId,
    ObjectId id,
  ) async {
    final address = addresses[id];
    return address != null && address['userId'] == userId ? address : null;
  }

  @override
  Future<List<Map<String, dynamic>>> findAddresses(
    ObjectId userId, {
    required int skip,
    required int limit,
  }) async => [
    for (final address
        in addresses.values
            .where((entry) => entry['userId'] == userId)
            .skip(skip)
            .take(limit))
      address,
  ];

  @override
  Future<int> countAddresses(ObjectId userId) async =>
      addresses.values.where((entry) => entry['userId'] == userId).length;

  @override
  Future<ObjectId> createAddress(
    ObjectId userId,
    Map<String, Object?> address,
    DateTime now,
  ) async {
    final id = ObjectId();
    addresses[id] = {
      '_id': id,
      'userId': userId,
      ...address,
      'createdAt': now,
      'updatedAt': now,
    };
    return id;
  }

  @override
  Future<bool> updateAddress(
    ObjectId userId,
    ObjectId id,
    Map<String, Object?> address,
    DateTime now,
  ) async {
    final existing = await findAddress(userId, id);
    if (existing == null) return false;
    addresses[id] = {...existing, ...address, 'updatedAt': now};
    return true;
  }

  @override
  Future<bool> deleteAddress(ObjectId userId, ObjectId id) async =>
      (await findAddress(userId, id)) != null && addresses.remove(id) != null;

  @override
  Future<bool> setDefaultAddress(
    ObjectId userId,
    ObjectId id,
    DateTime now,
  ) async {
    final existing = await findAddress(userId, id);
    if (existing == null) return false;
    for (final address in addresses.values) {
      if (address['userId'] == userId) address['isDefault'] = false;
    }
    existing['isDefault'] = true;
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> findShippingMethods({
    required int skip,
    required int limit,
  }) async => shippingMethods.values.skip(skip).take(limit).toList();

  @override
  Future<int> countShippingMethods() async => shippingMethods.length;

  @override
  Future<Map<String, dynamic>?> findShippingMethod(String code) async {
    final method = shippingMethods[code];
    return method?['isActive'] == true ? method : null;
  }

  @override
  Future<Map<String, dynamic>?> findOrderByIdempotencyKey(
    ObjectId userId,
    String key,
  ) async {
    final order = orders[key];
    return order != null && order['userId'] == userId ? order : null;
  }

  @override
  Future<bool> reserveStock(
    ObjectId productId,
    int quantity,
    int priceMinor,
    String currency,
    DateTime now,
  ) async {
    if (productId == failReservationFor) return false;
    final product = products[productId];
    if (product == null ||
        product['isActive'] != true ||
        product['priceMinor'] != priceMinor ||
        product['currency'] != currency ||
        (product['stock'] as int) < quantity) {
      return false;
    }
    product['stock'] = (product['stock'] as int) - quantity;
    return true;
  }

  @override
  Future<void> releaseStock(ObjectId productId, int quantity) async {
    final product = products[productId]!;
    product['stock'] = (product['stock'] as int) + quantity;
  }

  @override
  Future<bool> reserveCouponUse(
    String code,
    DateTime now,
    Map<String, Object?> expectedTerms,
  ) async {
    final coupon = coupons[code];
    if (failCouponReservation ||
        coupon == null ||
        coupon['isActive'] != true ||
        expectedTerms.entries.any(
          (entry) => coupon[entry.key] != entry.value,
        )) {
      return false;
    }
    final count = coupon['usageCount'] as int;
    final limit = coupon['usageLimit'] as int?;
    if (limit != null && count >= limit) return false;
    coupon['usageCount'] = count + 1;
    return true;
  }

  @override
  Future<void> releaseCouponUse(String code) async {
    final coupon = coupons[code]!;
    coupon['usageCount'] = (coupon['usageCount'] as int) - 1;
  }

  @override
  Future<void> insertOrder(Map<String, Object?> order) async {
    orders[order['idempotencyKey']! as String] = {
      ...order,
      'items': (order['items']! as List)
          .map((item) => item as Map<String, Object?>)
          .toList(),
    };
  }

  @override
  Future<void> clearCartForCheckout(
    ObjectId userId,
    List<Map<String, Object?>> expectedItems,
    String? expectedCouponCode,
    DateTime now,
  ) async {
    if (cart == null ||
        cart!['userId'] != userId ||
        cart!['couponCode'] != expectedCouponCode) {
      return;
    }
    cart!['items'] = <Map<String, Object?>>[];
    cart!.remove('couponCode');
  }

  @override
  Future<void> addCartItem(
    ObjectId userId,
    ObjectId productId,
    int quantity,
    int stock,
    DateTime now,
  ) async {
    cart ??= {'items': <Map<String, Object?>>[]};
    final items = cart!['items'] as List<Map<String, Object?>>;
    final itemIndex = items.indexWhere(
      (item) => item['productId'] == productId,
    );
    if (itemIndex == -1) {
      items.add({'productId': productId, 'quantity': quantity});
    } else {
      final oldQuantityValue = items[itemIndex]['quantity'];
      if (oldQuantityValue is! int) {
        throw StateError('Test cart quantity is invalid.');
      }
      final oldQuantity = oldQuantityValue;
      if (oldQuantity + quantity > stock) {
        throw const ApiException(
          statusCode: 409,
          code: 'insufficient_stock',
          message: 'Requested quantity exceeds available stock.',
        );
      }
      items[itemIndex]['quantity'] = oldQuantity + quantity;
    }
  }

  @override
  Future<void> setCartItemQuantity(
    ObjectId userId,
    ObjectId productId,
    int quantity,
    DateTime now,
  ) async {
    final items = cart!['items'] as List<Map<String, Object?>>;
    final item = items.firstWhere((entry) => entry['productId'] == productId);
    item['quantity'] = quantity;
  }

  @override
  Future<void> removeCartItem(
    ObjectId userId,
    ObjectId productId,
    DateTime now,
  ) async {
    final items = cart?['items'] as List<Map<String, Object?>>?;
    items?.removeWhere((item) => item['productId'] == productId);
  }

  @override
  Future<void> clearCart(ObjectId userId, DateTime now) async {
    cart = {'items': <Map<String, Object?>>[]};
  }

  @override
  Future<void> setCartCoupon(
    ObjectId userId,
    String code,
    DateTime now,
  ) async {
    cart ??= {'items': <Map<String, Object?>>[]};
    cart!['couponCode'] = code;
  }

  @override
  Future<void> removeCartCoupon(ObjectId userId, DateTime now) async {
    cart?.remove('couponCode');
  }

  @override
  Future<List<Map<String, dynamic>>> findWishlist(
    ObjectId userId, {
    required int skip,
    required int limit,
  }) async {
    final entries = wishlist.entries.toList()
      ..sort((first, second) => second.value.compareTo(first.value));
    return [
      for (final entry in entries.skip(skip).take(limit))
        {'productId': entry.key, 'addedAt': entry.value},
    ];
  }

  @override
  Future<int> countWishlist(ObjectId userId) async => wishlist.length;

  @override
  Future<bool> addWishlistItem(ObjectId userId, ObjectId productId) async {
    if (wishlist.containsKey(productId)) return false;
    wishlist[productId] = DateTime.now();
    return true;
  }

  @override
  Future<void> removeWishlistItem(ObjectId userId, ObjectId productId) async {
    wishlist.remove(productId);
  }
}

void main() {
  late _MemoryShopRepository repository;
  late CartService cartService;
  late WishlistService wishlistService;
  late CheckoutService checkoutService;
  final userId = ObjectId();
  final productId = ObjectId();
  final addressId = ObjectId();

  setUp(() {
    repository = _MemoryShopRepository()
      ..products[productId] = {
        '_id': productId,
        'name': 'Desk lamp',
        'slug': 'desk-lamp',
        'description': 'A test lamp.',
        'categoryId': ObjectId(),
        'priceMinor': 2500,
        'currency': 'USD',
        'stock': 8,
        'isActive': true,
        'images': [
          {'url': 'https://example.test/lamp.png'},
        ],
      };
    cartService = CartService(() async => repository);
    wishlistService = WishlistService(() async => repository);
    checkoutService = CheckoutService(() async => repository);
    repository.addresses[addressId] = {
      '_id': addressId,
      'userId': userId,
      'recipientName': 'Customer',
      'line1': '123 Main Street',
      'city': 'Phnom Penh',
      'postalCode': '12000',
      'countryCode': 'KH',
      'phone': '+85512345678',
      'createdAt': DateTime.now().toUtc(),
      'updatedAt': DateTime.now().toUtc(),
    };
    repository.shippingMethods['standard'] = {
      'code': 'standard',
      'name': 'Standard delivery',
      'priceMinor': 750,
      'currency': 'USD',
      'minimumDeliveryDays': 3,
      'maximumDeliveryDays': 5,
      'isActive': true,
    };
  });

  test('returns an empty cart with no chargeable items', () async {
    final cart = await cartService.getCart(userId);

    expect(cart['items'], isEmpty);
    expect(cart['subtotalMinor'], 0);
    expect(cart['totalMinor'], 0);
    expect(cart['canCheckout'], isFalse);
  });

  test('adds an in-stock item and calculates current price totals', () async {
    final cart = await cartService.addItem(userId, productId, 2);

    expect(cart['subtotalMinor'], 5000);
    expect(cart['totalMinor'], 5000);
    expect(cart['currency'], 'USD');
    expect(cart['canCheckout'], isTrue);
    final items = cart['items']! as List<Map<String, Object?>>;
    expect(items.single['quantity'], 2);
  });

  test('rejects adding more than available stock', () async {
    await expectLater(
      cartService.addItem(userId, productId, 9),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'insufficient_stock',
        ),
      ),
    );
    expect(repository.cart, isNull);
  });

  test(
    'applies percentage coupons to the server-calculated subtotal',
    () async {
      repository.cart = {
        'items': [
          {'productId': productId, 'quantity': 2},
        ],
      };
      repository.coupons['SAVE10'] = {
        'code': 'SAVE10',
        'kind': 'percent',
        'value': 10,
        'usageCount': 0,
        'isActive': true,
      };

      final cart = await cartService.applyCoupon(userId, ' save10 ');

      expect(cart['subtotalMinor'], 5000);
      expect(cart['discountMinor'], 500);
      expect(cart['totalMinor'], 4500);
      final coupon = cart['coupon']! as Map<String, Object?>;
      expect(coupon['valid'], isTrue);
    },
  );

  test('does not store an ineligible coupon', () async {
    repository.cart = {
      'items': [
        {'productId': productId, 'quantity': 1},
      ],
    };
    repository.coupons['EXPIRED'] = {
      'code': 'EXPIRED',
      'kind': 'fixed',
      'value': 500,
      'currency': 'USD',
      'usageCount': 0,
      'isActive': true,
      'expiresAt': DateTime.now().toUtc().subtract(const Duration(days: 1)),
    };

    await expectLater(
      cartService.applyCoupon(userId, 'EXPIRED'),
      throwsA(isA<ApiException>()),
    );
    expect(repository.cart!.containsKey('couponCode'), isFalse);
  });

  test('adds active products idempotently to the wishlist', () async {
    await wishlistService.add(userId, productId);
    final addedAgain = await wishlistService.add(userId, productId);
    final wishlist = await wishlistService.list(userId, const {});

    expect(repository.wishlist, hasLength(1));
    expect(addedAgain, isFalse);
    expect(wishlist['data']! as List, hasLength(1));
    expect(wishlist['pagination'], containsPair('total', 1));
  });

  test(
    'previews checkout from current address, stock, price, and shipping',
    () async {
      repository.cart = {
        'userId': userId,
        'items': [
          {'productId': productId, 'quantity': 2},
        ],
      };

      final preview = await checkoutService.preview(
        userId,
        addressId: addressId.oid,
        shippingMethodCode: 'standard',
      );

      expect(preview['subtotalMinor'], 5000);
      expect(preview['discountMinor'], 0);
      expect(preview['shippingMinor'], 750);
      expect(preview['totalMinor'], 5750);
      expect(preview['currency'], 'USD');
    },
  );

  test('rejects checkout using another user address', () async {
    await expectLater(
      checkoutService.preview(
        ObjectId(),
        addressId: addressId.oid,
        shippingMethodCode: 'standard',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'invalid_delivery_address',
        ),
      ),
    );
  });

  test(
    'creates an order, snapshots products, and replays idempotently',
    () async {
      repository.cart = {
        'userId': userId,
        'items': [
          {'productId': productId, 'quantity': 2},
        ],
      };
      repository.coupons['SAVE10'] = {
        'code': 'SAVE10',
        'kind': 'percent',
        'value': 10,
        'usageCount': 0,
        'usageLimit': 5,
        'isActive': true,
      };
      repository.cart!['couponCode'] = 'SAVE10';

      final result = await checkoutService.createOrder(
        userId,
        addressId: addressId.oid,
        shippingMethodCode: 'standard',
        idempotencyKey: 'checkout-key-0001',
      );
      final order = result['order']! as Map<String, Object?>;
      final orderItems = order['items']! as List<Map<String, Object?>>;
      expect(result['replayed'], isFalse);
      expect(order['status'], 'awaiting_fulfillment');
      expect(order['subtotalMinor'], 5000);
      expect(order['discountMinor'], 500);
      expect(order['totalMinor'], 5250);
      expect(orderItems.single['name'], 'Desk lamp');
      expect(orderItems.single['unitPriceMinor'], 2500);
      expect(repository.products[productId]!['stock'], 6);
      expect(repository.coupons['SAVE10']!['usageCount'], 1);
      expect(repository.cart!['items'], isEmpty);

      final replay = await checkoutService.createOrder(
        userId,
        addressId: addressId.oid,
        shippingMethodCode: 'standard',
        idempotencyKey: 'checkout-key-0001',
      );
      expect(replay['replayed'], isTrue);
      expect(repository.orders, hasLength(1));
      expect(repository.products[productId]!['stock'], 6);
      expect(repository.coupons['SAVE10']!['usageCount'], 1);
    },
  );

  test('rejects reusing an idempotency key with a different address', () async {
    repository.cart = {
      'userId': userId,
      'items': [
        {'productId': productId, 'quantity': 1},
      ],
    };
    await checkoutService.createOrder(
      userId,
      addressId: addressId.oid,
      shippingMethodCode: 'standard',
      idempotencyKey: 'checkout-key-0002',
    );

    await expectLater(
      checkoutService.createOrder(
        userId,
        addressId: ObjectId().oid,
        shippingMethodCode: 'standard',
        idempotencyKey: 'checkout-key-0002',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'idempotency_key_reused',
        ),
      ),
    );
  });

  test(
    'compensates stock reservation when coupon use is unavailable',
    () async {
      repository.cart = {
        'userId': userId,
        'items': [
          {'productId': productId, 'quantity': 2},
        ],
        'couponCode': 'SAVE10',
      };
      repository.coupons['SAVE10'] = {
        'code': 'SAVE10',
        'kind': 'percent',
        'value': 10,
        'usageCount': 0,
        'usageLimit': 5,
        'isActive': true,
      };
      repository.failCouponReservation = true;

      await expectLater(
        checkoutService.createOrder(
          userId,
          addressId: addressId.oid,
          shippingMethodCode: 'standard',
          idempotencyKey: 'checkout-key-0003',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(repository.products[productId]!['stock'], 8);
      expect(repository.coupons['SAVE10']!['usageCount'], 0);
      expect(repository.orders, isEmpty);
    },
  );

  test(
    'compensates earlier stock reservations if a later product changes',
    () async {
      final secondProductId = ObjectId();
      repository
        ..products[secondProductId] = {
          ...repository.products[productId]!,
          '_id': secondProductId,
          'name': 'Table lamp',
          'slug': 'table-lamp',
        }
        ..cart = {
          'userId': userId,
          'items': [
            {'productId': productId, 'quantity': 2},
            {'productId': secondProductId, 'quantity': 1},
          ],
        }
        ..failReservationFor = secondProductId;

      await expectLater(
        checkoutService.createOrder(
          userId,
          addressId: addressId.oid,
          shippingMethodCode: 'standard',
          idempotencyKey: 'checkout-key-0004',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(repository.products[productId]!['stock'], 8);
      expect(repository.products[secondProductId]!['stock'], 8);
      expect(repository.orders, isEmpty);
    },
  );
}
