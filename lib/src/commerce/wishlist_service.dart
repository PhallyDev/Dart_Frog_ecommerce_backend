import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/commerce/shop_repository.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/models/pagination.dart';
import 'package:shop_ease_ecommerce/src/models/product.dart';

/// User-owned wishlist operations.
class WishlistService {
  /// Creates wishlist operations backed by the supplied repository provider.
  WishlistService(this._repositoryProvider);

  final ShopRepositoryProvider _repositoryProvider;

  /// Lists the authenticated user's wishlist page and current product data.
  Future<Map<String, Object?>> list(
    ObjectId userId,
    Map<String, String> parameters,
  ) async {
    final unknown = parameters.keys.toSet().difference({'page', 'limit'});
    if (unknown.isNotEmpty) {
      throw ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_query',
        message: 'Unsupported query parameter: ${unknown.first}.',
      );
    }

    final Pagination pagination;
    try {
      pagination = Pagination.parse(parameters);
    } on FormatException catch (error) {
      throw ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_query',
        message: error.message,
      );
    }
    final repository = await _repositoryProvider();
    final documents = await repository.findWishlist(
      userId,
      skip: pagination.offset,
      limit: pagination.limit,
    );
    final productIds = <ObjectId>{};
    for (final document in documents) {
      final id = document['productId'];
      if (id is! ObjectId) throw StateError('Wishlist product ID is invalid.');
      productIds.add(id);
    }
    final products = await repository.findProducts(productIds);
    final byId = {
      for (final product in products)
        if (product['_id'] is ObjectId) product['_id'] as ObjectId: product,
    };
    final total = await repository.countWishlist(userId);

    return {
      'data': documents.map((document) {
        final productId = document['productId'] as ObjectId;
        final productDocument = byId[productId];
        final addedAt = document['addedAt'];
        if (addedAt is! DateTime) {
          throw StateError('Wishlist timestamp is invalid.');
        }
        return <String, Object?>{
          'productId': productId.oid,
          'addedAt': addedAt.toUtc().toIso8601String(),
          'available':
              productDocument != null && productDocument['isActive'] == true,
          'product': productDocument == null
              ? null
              : Product.fromDocument(productDocument).toJson(),
        };
      }).toList(),
      'pagination': pagination.metadata(total),
    };
  }

  /// Adds an active product idempotently to the user's wishlist.
  Future<bool> add(ObjectId userId, ObjectId productId) async {
    final repository = await _repositoryProvider();
    final product = await repository.findProduct(productId);
    if (product == null || product['isActive'] != true) {
      throw const ApiException(
        statusCode: HttpStatus.notFound,
        code: 'product_not_found',
        message: 'Product not found.',
      );
    }
    return repository.addWishlistItem(userId, productId);
  }

  /// Removes a product from the user's wishlist.
  Future<void> remove(ObjectId userId, ObjectId productId) async {
    final repository = await _repositoryProvider();
    await repository.removeWishlistItem(userId, productId);
  }
}
