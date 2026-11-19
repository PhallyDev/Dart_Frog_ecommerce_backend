import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/commerce/coupon_pricing.dart';
import 'package:shop_ease_ecommerce/src/commerce/shipping_service.dart';
import 'package:shop_ease_ecommerce/src/commerce/shop_repository.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/models/product.dart';

/// Revalidates checkout inputs, reserves inventory, and creates orders.
class CheckoutService {
  /// Creates checkout operations backed by the supplied repository provider.
  CheckoutService(this._repositoryProvider);

  final ShopRepositoryProvider _repositoryProvider;

  /// Builds a server-calculated checkout quote without reserving inventory.
  Future<Map<String, Object?>> preview(
    ObjectId userId, {
    required String addressId,
    required String shippingMethodCode,
  }) async {
    final repository = await _repositoryProvider();
    final quote = await _buildQuote(
      repository,
      userId,
      addressId: addressId,
      shippingMethodCode: shippingMethodCode,
    );
    return quote.toJson();
  }

  /// Creates one idempotent order after reserving stock and coupon usage.
  Future<Map<String, Object?>> createOrder(
    ObjectId userId, {
    required String addressId,
    required String shippingMethodCode,
    required String idempotencyKey,
  }) async {
    _validateIdempotencyKey(idempotencyKey);
    final repository = await _repositoryProvider();
    final fingerprint = _fingerprint(addressId, shippingMethodCode);
    final priorOrder = await repository.findOrderByIdempotencyKey(
      userId,
      idempotencyKey,
    );
    if (priorOrder != null) {
      return _replayOrder(priorOrder, fingerprint);
    }
    final quote = await _buildQuote(
      repository,
      userId,
      addressId: addressId,
      shippingMethodCode: shippingMethodCode,
    );

    final now = DateTime.now().toUtc();
    final orderId = ObjectId();
    final orderNumber = 'SE-${ObjectId().oid.toUpperCase()}';
    final reserved = <_ReservedStock>[];
    var couponReserved = false;
    try {
      for (final item in quote.items) {
        final didReserve = await repository.reserveStock(
          item.productId,
          item.quantity,
          item.unitPriceMinor,
          item.currency,
          now,
        );
        if (!didReserve) _throwInventoryChanged();
        reserved.add(
          _ReservedStock(item.productId, item.quantity),
        );
      }

      final couponCode = quote.couponCode;
      if (couponCode != null) {
        couponReserved = await repository.reserveCouponUse(
          couponCode,
          now,
          quote.couponTerms,
        );
        if (!couponReserved) _throwCouponUnavailable();
      }

      await repository.insertOrder({
        '_id': orderId,
        'userId': userId,
        'orderNumber': orderNumber,
        'idempotencyKey': idempotencyKey,
        'requestFingerprint': fingerprint,
        'status': 'awaiting_fulfillment',
        'items': quote.items.map((item) => item.toJson()).toList(),
        'addressSnapshot': quote.addressSnapshot,
        'shippingSnapshot': quote.shippingSnapshot,
        'subtotalMinor': quote.subtotalMinor,
        'discountMinor': quote.discountMinor,
        'shippingMinor': quote.shippingMinor,
        'totalMinor': quote.totalMinor,
        'currency': quote.currency,
        if (couponCode != null) 'couponCode': couponCode,
        'createdAt': now,
        'updatedAt': now,
      });
    } catch (error, stackTrace) {
      for (final item in reserved.reversed) {
        await repository.releaseStock(item.productId, item.quantity);
      }
      final reservedCouponCode = quote.couponCode;
      if (couponReserved && reservedCouponCode != null) {
        await repository.releaseCouponUse(reservedCouponCode);
      }
      if (_isDuplicateKey(error)) {
        final existing = await repository.findOrderByIdempotencyKey(
          userId,
          idempotencyKey,
        );
        if (existing != null) return _replayOrder(existing, fingerprint);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    await repository.clearCartForCheckout(
      userId,
      quote.expectedCartItems,
      quote.expectedCouponCode,
      now,
    );
    return {
      'order': quote.orderResponse(
        id: orderId.oid,
        orderNumber: orderNumber,
        status: 'awaiting_fulfillment',
        createdAt: now,
      ),
      'replayed': false,
    };
  }

  Future<_CheckoutQuote> _buildQuote(
    ShopRepository repository,
    ObjectId userId, {
    required String addressId,
    required String shippingMethodCode,
  }) async {
    final addressObjectId = _parseObjectId(addressId, 'address');
    final address = await repository.findAddress(userId, addressObjectId);
    if (address == null) {
      throw const ApiException(
        statusCode: HttpStatus.unprocessableEntity,
        code: 'invalid_delivery_address',
        message: 'Select a saved delivery address.',
      );
    }
    final shippingCode = shippingMethodCode.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,32}$').hasMatch(shippingCode)) {
      throw const ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_shipping_method',
        message: 'A valid shipping method code is required.',
      );
    }
    final shipping = await repository.findShippingMethod(shippingCode);
    if (shipping == null) _throwShippingMethodUnavailable();
    final shippingSnapshot = ShippingService.publicShippingMethod(shipping);
    final cart = await repository.findCart(userId);
    final rawItems = cart?['items'];
    if (rawItems is! List || rawItems.isEmpty) _throwEmptyCart();

    final quantities = <ObjectId, int>{};
    for (final rawItem in rawItems) {
      if (rawItem is! Map) {
        throw StateError('Cart item document is invalid.');
      }
      final rawProductId = rawItem['productId'];
      final rawQuantity = rawItem['quantity'];
      if (rawProductId is! ObjectId ||
          rawQuantity is! num ||
          rawQuantity < 1 ||
          rawQuantity != rawQuantity.toInt() ||
          rawQuantity > 99) {
        throw StateError('Cart item document is invalid.');
      }
      final productId = rawProductId;
      quantities.update(
        productId,
        (quantity) => quantity + rawQuantity.toInt(),
        ifAbsent: rawQuantity.toInt,
      );
    }
    if (quantities.values.any((quantity) => quantity > 99)) {
      _throwInventoryChanged();
    }
    final products = await repository.findProducts(quantities.keys.toSet());
    final productDocuments = {
      for (final product in products)
        if (product['_id'] is ObjectId) product['_id'] as ObjectId: product,
    };
    final items = <_OrderItemSnapshot>[];
    String? currency;
    var subtotal = 0;
    for (final entry in quantities.entries) {
      final document = productDocuments[entry.key];
      if (document == null ||
          document['isActive'] != true ||
          document['stock'] is! num ||
          (document['stock'] as num) < entry.value) {
        _throwInventoryChanged();
      }
      final product = Product.fromDocument(document);
      if (currency != null && currency != product.currency) {
        _throwCartCurrencyMismatch();
      }
      currency = product.currency;
      final imageUrl = product.images.isEmpty
          ? null
          : product.images.first['url'] as String?;
      final line = _OrderItemSnapshot(
        productId: product.id,
        name: product.name,
        sku: product.sku,
        quantity: entry.value,
        unitPriceMinor: product.priceMinor,
        currency: product.currency,
        imageUrl: imageUrl,
      );
      items.add(line);
      subtotal += product.priceMinor * entry.value;
    }
    final quoteCurrency = currency;
    if (quoteCurrency == null ||
        shippingSnapshot['currency'] != quoteCurrency) {
      _throwCartCurrencyMismatch();
    }
    final rawCouponCode = cart?['couponCode'];
    final couponCode = rawCouponCode is String ? rawCouponCode : null;
    var discount = 0;
    var couponTerms = <String, Object?>{};
    if (couponCode != null) {
      final coupon = await repository.findCoupon(couponCode);
      final eligibleDiscount = calculateCouponDiscount(
        coupon,
        subtotal,
        quoteCurrency,
        DateTime.now().toUtc(),
      );
      if (eligibleDiscount == null) _throwCouponUnavailable();
      discount = eligibleDiscount;
      couponTerms = _couponTerms(coupon);
    }

    final expectedCartItems = <Map<String, Object?>>[];
    for (final rawItem in rawItems) {
      final item = rawItem as Map;
      expectedCartItems.add({
        'productId': item['productId'] as ObjectId,
        'quantity': (item['quantity'] as num).toInt(),
        if (item['addedAt'] is DateTime) 'addedAt': item['addedAt'],
      });
    }
    return _CheckoutQuote(
      items: items,
      addressSnapshot: _addressSnapshot(address),
      shippingSnapshot: shippingSnapshot,
      subtotalMinor: subtotal,
      discountMinor: discount,
      shippingMinor: shippingSnapshot['priceMinor']! as int,
      totalMinor:
          subtotal - discount + (shippingSnapshot['priceMinor']! as int),
      currency: quoteCurrency,
      couponCode: couponCode,
      expectedCartItems: expectedCartItems,
      expectedCouponCode: couponCode,
      couponTerms: couponTerms,
    );
  }

  static Map<String, Object?> _couponTerms(Map<String, dynamic>? coupon) {
    if (coupon == null) return const {};
    return {
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
        if (coupon.containsKey(field)) field: coupon[field],
    };
  }

  static Map<String, Object?> _addressSnapshot(
    Map<String, dynamic> address,
  ) {
    final id = address['_id'];
    if (id is! ObjectId) throw StateError('Address document is invalid.');
    return {
      'addressId': id.oid,
      'recipientName': address['recipientName'],
      'line1': address['line1'],
      if (address['line2'] is String) 'line2': address['line2'],
      'city': address['city'],
      if (address['region'] is String) 'region': address['region'],
      'postalCode': address['postalCode'],
      'countryCode': address['countryCode'],
      if (address['phone'] is String) 'phone': address['phone'],
    };
  }

  static String _fingerprint(String addressId, String shippingMethodCode) {
    final normalized = {
      'addressId': addressId.toLowerCase(),
      'shippingMethodCode': shippingMethodCode.trim(),
    };
    return sha256.convert(utf8.encode(jsonEncode(normalized))).toString();
  }

  static Map<String, Object?> _replayOrder(
    Map<String, dynamic> existing,
    String fingerprint,
  ) {
    if (existing['requestFingerprint'] != fingerprint) {
      throw const ApiException(
        statusCode: HttpStatus.conflict,
        code: 'idempotency_key_reused',
        message: 'This idempotency key was already used for another checkout.',
      );
    }
    final id = existing['_id'];
    final orderNumber = existing['orderNumber'];
    final status = existing['status'];
    final createdAt = existing['createdAt'];
    if (id is! ObjectId ||
        orderNumber is! String ||
        status is! String ||
        createdAt is! DateTime) {
      throw StateError('Stored order document is invalid.');
    }
    return {
      'order': _publicOrder(existing),
      'replayed': true,
    };
  }

  static Map<String, Object?> _publicOrder(Map<String, dynamic> order) {
    final id = order['_id'];
    final createdAt = order['createdAt'];
    if (id is! ObjectId || createdAt is! DateTime) {
      throw StateError('Stored order document is invalid.');
    }
    return {
      'id': id.oid,
      'orderNumber': order['orderNumber'],
      'status': order['status'],
      'items': order['items'],
      'address': order['addressSnapshot'],
      'shipping': order['shippingSnapshot'],
      'subtotalMinor': order['subtotalMinor'],
      'discountMinor': order['discountMinor'],
      'shippingMinor': order['shippingMinor'],
      'totalMinor': order['totalMinor'],
      'currency': order['currency'],
      if (order['couponCode'] is String) 'couponCode': order['couponCode'],
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  static void _validateIdempotencyKey(String key) {
    if (!RegExp(r'^[A-Za-z0-9._:-]{8,128}$').hasMatch(key)) {
      throw const ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_idempotency_key',
        message: 'Idempotency-Key must be 8–128 valid ASCII characters.',
      );
    }
  }

  static ObjectId _parseObjectId(String value, String resource) {
    if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value)) {
      throw ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_id',
        message: 'The $resource ID is invalid.',
      );
    }
    return ObjectId.fromHexString(value);
  }

  static bool _isDuplicateKey(Object error) {
    if (error is MongoDartError) {
      // mongo_dart represents MongoDB duplicate-key server failures as errors.
      // ignore: avoid_catching_errors
      return error.mongoCode == 11000 || error.message.contains('E11000');
    }
    return false;
  }

  static Never _throwEmptyCart() {
    throw const ApiException(
      statusCode: HttpStatus.unprocessableEntity,
      code: 'empty_cart',
      message: 'Add an available product before checkout.',
    );
  }

  static Never _throwInventoryChanged() {
    throw const ApiException(
      statusCode: HttpStatus.conflict,
      code: 'inventory_changed',
      message:
          'Product availability or price changed. Review your cart and retry.',
    );
  }

  static Never _throwShippingMethodUnavailable() {
    throw const ApiException(
      statusCode: HttpStatus.unprocessableEntity,
      code: 'shipping_method_unavailable',
      message: 'The selected shipping method is unavailable.',
    );
  }

  static Never _throwCouponUnavailable() {
    throw const ApiException(
      statusCode: HttpStatus.unprocessableEntity,
      code: 'coupon_not_applicable',
      message: 'The applied coupon is no longer available.',
    );
  }

  static Never _throwCartCurrencyMismatch() {
    throw const ApiException(
      statusCode: HttpStatus.conflict,
      code: 'cart_currency_mismatch',
      message: 'Cart and shipping method currencies must match.',
    );
  }
}

class _ReservedStock {
  const _ReservedStock(this.productId, this.quantity);

  final ObjectId productId;
  final int quantity;
}

class _CheckoutQuote {
  const _CheckoutQuote({
    required this.items,
    required this.addressSnapshot,
    required this.shippingSnapshot,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.shippingMinor,
    required this.totalMinor,
    required this.currency,
    required this.couponCode,
    required this.expectedCartItems,
    required this.expectedCouponCode,
    required this.couponTerms,
  });

  final List<_OrderItemSnapshot> items;
  final Map<String, Object?> addressSnapshot;
  final Map<String, Object?> shippingSnapshot;
  final int subtotalMinor;
  final int discountMinor;
  final int shippingMinor;
  final int totalMinor;
  final String currency;
  final String? couponCode;
  final List<Map<String, Object?>> expectedCartItems;
  final String? expectedCouponCode;
  final Map<String, Object?> couponTerms;

  Map<String, Object?> toJson() => {
    'items': items.map((item) => item.toJson()).toList(),
    'address': addressSnapshot,
    'shipping': shippingSnapshot,
    'subtotalMinor': subtotalMinor,
    'discountMinor': discountMinor,
    'shippingMinor': shippingMinor,
    'totalMinor': totalMinor,
    'currency': currency,
    if (couponCode != null) 'couponCode': couponCode,
  };

  Map<String, Object?> orderResponse({
    required String id,
    required String orderNumber,
    required String status,
    required DateTime createdAt,
  }) => {
    'id': id,
    'orderNumber': orderNumber,
    'status': status,
    ...toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

class _OrderItemSnapshot {
  const _OrderItemSnapshot({
    required this.productId,
    required this.name,
    required this.sku,
    required this.quantity,
    required this.unitPriceMinor,
    required this.currency,
    required this.imageUrl,
  });

  final ObjectId productId;
  final String name;
  final String? sku;
  final int quantity;
  final int unitPriceMinor;
  final String currency;
  final String? imageUrl;

  Map<String, Object?> toJson() => {
    'productId': productId.oid,
    'name': name,
    if (sku != null) 'sku': sku,
    'quantity': quantity,
    'unitPriceMinor': unitPriceMinor,
    'currency': currency,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };
}
