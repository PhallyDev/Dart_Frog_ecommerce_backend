import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/commerce/coupon_pricing.dart';
import 'package:shop_ease_ecommerce/src/commerce/shop_repository.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/models/product.dart';

/// Shopping cart operations with server-side product, stock, and coupon checks.
class CartService {
  /// Creates service operations backed by the supplied repository provider.
  CartService(this._repositoryProvider);

  final ShopRepositoryProvider _repositoryProvider;

  static const _maximumQuantity = 99;
  static final _couponPattern = RegExp(r'^[A-Z0-9_-]{1,32}$');

  /// Returns current cart entries, prices, coupon evaluation, and totals.
  Future<Map<String, Object?>> getCart(ObjectId userId) async {
    final repository = await _repositoryProvider();
    return _cartResponse(repository, userId);
  }

  /// Adds a quantity of an active in-stock product to the user's cart.
  Future<Map<String, Object?>> addItem(
    ObjectId userId,
    ObjectId productId,
    int quantity,
  ) async {
    _validateQuantity(quantity);
    final repository = await _repositoryProvider();
    final product = await repository.findProduct(productId);
    if (product == null || product['isActive'] != true) {
      _throwProductNotFound();
    }
    final parsed = Product.fromDocument(product);
    if (parsed.stock < quantity) _throwInsufficientStock();

    final cart = await repository.findCart(userId);
    final existingProducts = await _productsInCart(repository, cart);
    for (final existing in existingProducts.values) {
      final itemProduct = Product.fromDocument(existing);
      if (itemProduct.currency != parsed.currency) _throwCurrencyMismatch();
    }
    await repository.addCartItem(
      userId,
      productId,
      quantity,
      parsed.stock,
      DateTime.now().toUtc(),
    );
    return _cartResponse(repository, userId);
  }

  /// Sets the quantity of an existing cart item.
  Future<Map<String, Object?>> updateItemQuantity(
    ObjectId userId,
    ObjectId productId,
    int quantity,
  ) async {
    _validateQuantity(quantity);
    final repository = await _repositoryProvider();
    final product = await repository.findProduct(productId);
    if (product == null || product['isActive'] != true) {
      _throwProductNotFound();
    }
    final parsed = Product.fromDocument(product);
    if (parsed.stock < quantity) _throwInsufficientStock();
    final cart = await repository.findCart(userId);
    final existing = _cartItemQuantity(cart, productId);
    if (existing == null) _throwCartItemNotFound();
    final products = await _productsInCart(repository, cart);
    for (final itemProduct in products.values) {
      if (Product.fromDocument(itemProduct).currency != parsed.currency) {
        _throwCurrencyMismatch();
      }
    }
    await repository.setCartItemQuantity(
      userId,
      productId,
      quantity,
      DateTime.now().toUtc(),
    );
    return _cartResponse(repository, userId);
  }

  /// Removes one item from the user's cart.
  Future<Map<String, Object?>> removeItem(
    ObjectId userId,
    ObjectId productId,
  ) async {
    final repository = await _repositoryProvider();
    await repository.removeCartItem(userId, productId, DateTime.now().toUtc());
    return _cartResponse(repository, userId);
  }

  /// Clears all cart items and the applied coupon.
  Future<Map<String, Object?>> clearCart(ObjectId userId) async {
    final repository = await _repositoryProvider();
    await repository.clearCart(userId, DateTime.now().toUtc());
    return _cartResponse(repository, userId);
  }

  /// Validates and applies a coupon to the current cart.
  Future<Map<String, Object?>> applyCoupon(
    ObjectId userId,
    String rawCode,
  ) async {
    final code = rawCode.trim().toUpperCase();
    if (!_couponPattern.hasMatch(code)) {
      throw const ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_coupon_code',
        message: 'Coupon code must contain 1–32 letters, digits, "_" or "-".',
      );
    }
    final repository = await _repositoryProvider();
    final cart = await repository.findCart(userId);
    final state = await _cartState(repository, cart);
    if (state.items.isEmpty || !state.canCheckout || state.currency == null) {
      _throwCouponNotApplicable();
    }
    final coupon = await repository.findCoupon(code);
    final discount = calculateCouponDiscount(
      coupon,
      state.subtotalMinor,
      state.currency,
      DateTime.now().toUtc(),
    );
    if (discount == null) _throwCouponNotApplicable();

    await repository.setCartCoupon(userId, code, DateTime.now().toUtc());
    return _cartResponse(repository, userId);
  }

  /// Removes the applied coupon.
  Future<Map<String, Object?>> removeCoupon(ObjectId userId) async {
    final repository = await _repositoryProvider();
    await repository.removeCartCoupon(userId, DateTime.now().toUtc());
    return _cartResponse(repository, userId);
  }

  Future<Map<String, Object?>> _cartResponse(
    ShopRepository repository,
    ObjectId userId,
  ) async {
    final cart = await repository.findCart(userId);
    final state = await _cartState(repository, cart);
    final couponCode = cart?['couponCode'];
    final couponDocument = couponCode is String
        ? await repository.findCoupon(couponCode)
        : null;
    final couponDiscount = couponCode is String
        ? calculateCouponDiscount(
            couponDocument,
            state.subtotalMinor,
            state.currency,
            DateTime.now().toUtc(),
          )
        : null;
    final discount = couponDiscount ?? 0;
    return {
      'items': state.items,
      'currency': state.currency,
      'subtotalMinor': state.subtotalMinor,
      'discountMinor': discount,
      'totalMinor': state.subtotalMinor - discount,
      'coupon': couponCode is String
          ? {
              'code': couponCode,
              'valid': couponDiscount != null,
              'discountMinor': discount,
            }
          : null,
      'canCheckout': state.canCheckout,
    };
  }

  Future<_CartState> _cartState(
    ShopRepository repository,
    Map<String, dynamic>? cart,
  ) async {
    final rawItems = cart?['items'] ?? const <Object?>[];
    if (rawItems is! List) throw StateError('Cart items are invalid.');
    for (final rawItem in rawItems) {
      if (rawItem is! Map ||
          rawItem['productId'] is! ObjectId ||
          rawItem['quantity'] is! num ||
          (rawItem['quantity'] as num) < 1 ||
          (rawItem['quantity'] as num) !=
              (rawItem['quantity'] as num).toInt()) {
        throw StateError('Cart item document is invalid.');
      }
    }
    final products = await _productsInCart(repository, cart);
    final items = <Map<String, Object?>>[];
    var subtotal = 0;
    String? currency;
    var canCheckout = rawItems.isNotEmpty;
    for (final rawItem in rawItems) {
      final item = rawItem as Map;
      final productId = item['productId'] as ObjectId;
      final quantity = (item['quantity'] as num).toInt();
      final document = products[productId];
      if (document == null) {
        canCheckout = false;
        items.add({
          'productId': productId.oid,
          'quantity': quantity,
          'available': false,
          'product': null,
          'lineTotalMinor': null,
        });
        continue;
      }
      final product = Product.fromDocument(document);
      if (currency != null && currency != product.currency) {
        throw StateError('Cart contains products in different currencies.');
      }
      currency = product.currency;
      final active = document['isActive'] == true;
      final available = active && product.stock >= quantity;
      if (!available) canCheckout = false;
      final lineTotal = product.priceMinor * quantity;
      subtotal += lineTotal;
      items.add({
        'productId': product.id.oid,
        'quantity': quantity,
        'available': available,
        'product': {
          'id': product.id.oid,
          'name': product.name,
          'slug': product.slug,
          'priceMinor': product.priceMinor,
          'currency': product.currency,
          if (product.images.isNotEmpty) 'image': product.images.first,
        },
        'lineTotalMinor': lineTotal,
      });
    }
    return _CartState(
      items: items,
      subtotalMinor: subtotal,
      currency: currency,
      canCheckout: canCheckout,
    );
  }

  Future<Map<ObjectId, Map<String, dynamic>>> _productsInCart(
    ShopRepository repository,
    Map<String, dynamic>? cart,
  ) async {
    final rawItems = cart?['items'] ?? const <Object?>[];
    if (rawItems is! List) throw StateError('Cart items are invalid.');
    final ids = <ObjectId>{};
    for (final item in rawItems) {
      if (item is! Map || item['productId'] is! ObjectId) {
        throw StateError('Cart item document is invalid.');
      }
      ids.add(item['productId'] as ObjectId);
    }
    final documents = await repository.findProducts(ids);
    return {
      for (final document in documents)
        if (document['_id'] is ObjectId) document['_id'] as ObjectId: document,
    };
  }

  int? _cartItemQuantity(Map<String, dynamic>? cart, ObjectId productId) {
    final items = cart?['items'] ?? const <Object?>[];
    if (items is! List) throw StateError('Cart items are invalid.');
    for (final item in items) {
      if (item is Map && item['productId'] == productId) {
        final quantity = item['quantity'];
        if (quantity is num && quantity == quantity.toInt()) {
          return quantity.toInt();
        }
        throw StateError('Cart item quantity is invalid.');
      }
    }
    return null;
  }

  static void _validateQuantity(int quantity) {
    if (quantity < 1 || quantity > _maximumQuantity) {
      throw const ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_quantity',
        message: 'Quantity must be an integer between 1 and 99.',
      );
    }
  }

  static Never _throwProductNotFound() {
    throw const ApiException(
      statusCode: HttpStatus.notFound,
      code: 'product_not_found',
      message: 'Product not found.',
    );
  }

  static Never _throwInsufficientStock() {
    throw const ApiException(
      statusCode: HttpStatus.conflict,
      code: 'insufficient_stock',
      message: 'Requested quantity exceeds available stock.',
    );
  }

  static Never _throwCartItemNotFound() {
    throw const ApiException(
      statusCode: HttpStatus.notFound,
      code: 'cart_item_not_found',
      message: 'Cart item not found.',
    );
  }

  static Never _throwCurrencyMismatch() {
    throw const ApiException(
      statusCode: HttpStatus.conflict,
      code: 'cart_currency_mismatch',
      message: 'All items in a cart must use the same currency.',
    );
  }

  static Never _throwCouponNotApplicable() {
    throw const ApiException(
      statusCode: HttpStatus.unprocessableEntity,
      code: 'coupon_not_applicable',
      message: 'Coupon is invalid or does not apply to this cart.',
    );
  }
}

class _CartState {
  const _CartState({
    required this.items,
    required this.subtotalMinor,
    required this.currency,
    required this.canCheckout,
  });

  final List<Map<String, Object?>> items;
  final int subtotalMinor;
  final String? currency;
  final bool canCheckout;
}
