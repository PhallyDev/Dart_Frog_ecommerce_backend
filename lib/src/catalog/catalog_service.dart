import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/catalog/catalog_query.dart';
import 'package:shop_ease_ecommerce/src/database/collection_names.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/models/category.dart';
import 'package:shop_ease_ecommerce/src/models/pagination.dart';
import 'package:shop_ease_ecommerce/src/models/product.dart';
import 'package:shop_ease_ecommerce/src/models/review.dart';

/// Read-only business operations for the public product catalog.
class CatalogService {
  /// Creates catalog operations backed by the shared MongoDB connection.
  CatalogService(MongoDatabase database)
    : _databaseProvider = (() async => database);

  /// Creates catalog operations that open the database only when queried.
  CatalogService.fromProvider(this._databaseProvider);

  final Future<MongoDatabase> Function() _databaseProvider;

  /// Lists active categories in display order.
  Future<Map<String, Object?>> listCategories(
    Map<String, String> parameters,
  ) async {
    _validateParameters(parameters, const {'page', 'limit'});
    final pagination = _parsePagination(parameters);
    final database = await _databaseProvider();
    final categories = database.collection(CollectionNames.categories);
    final selector = where
        .eq('isActive', true)
        .sortBy('sortOrder')
        .sortBy('name')
        .skip(pagination.offset)
        .limit(pagination.limit);
    final documents = await categories.find(selector).toList();
    final total = await categories.count(where.eq('isActive', true));
    return {
      'data': documents
          .map(Category.fromDocument)
          .map((item) => item.toJson())
          .toList(),
      'pagination': pagination.metadata(total),
    };
  }

  /// Searches active products using validated filtering and sort options.
  Future<Map<String, Object?>> listProducts(
    Map<String, String> parameters,
  ) async {
    final query = _parseCatalogQuery(parameters);
    final database = await _databaseProvider();
    final collection = database.collection(CollectionNames.products);
    ObjectId? categoryId;
    if (query.categorySlug != null) {
      final category = await database
          .collection(CollectionNames.categories)
          .findOne(where.eq('slug', query.categorySlug).eq('isActive', true));
      final id = category?['_id'];
      if (id is! ObjectId) {
        return {
          'data': <Object?>[],
          'pagination': query.pagination.metadata(0),
        };
      }
      categoryId = id;
    }

    final total = await collection.count(_productSelector(query, categoryId));
    final selector = _productSelector(query, categoryId)
      ..skip(query.pagination.offset)
      ..limit(query.pagination.limit);
    if (query.sort == 'relevance') {
      selector.metaTextScore('searchScore');
    }
    final documents = await collection.find(selector).toList();
    return {
      'data': documents
          .map(Product.fromDocument)
          .map((item) => item.toJson())
          .toList(),
      'pagination': query.pagination.metadata(total),
    };
  }

  /// Returns one active product or a not-found response.
  Future<Map<String, Object?>> getProduct(String id) async {
    final objectId = _parseObjectId(id, 'product');
    final database = await _databaseProvider();
    final document = await database
        .collection(CollectionNames.products)
        .findOne(where.id(objectId).eq('isActive', true));
    if (document == null) {
      throw const ApiException(
        statusCode: HttpStatus.notFound,
        code: 'product_not_found',
        message: 'Product not found.',
      );
    }
    return Product.fromDocument(document).toJson();
  }

  /// Returns image metadata for one active product.
  Future<Map<String, Object?>> getProductImages(String id) async {
    final objectId = _parseObjectId(id, 'product');
    final database = await _databaseProvider();
    final document = await database
        .collection(CollectionNames.products)
        .findOne(where.id(objectId).eq('isActive', true).fields(['images']));
    if (document == null) {
      throw const ApiException(
        statusCode: HttpStatus.notFound,
        code: 'product_not_found',
        message: 'Product not found.',
      );
    }
    return {
      'productId': objectId.oid,
      'images': Product.parseImages(document['images']),
    };
  }

  /// Lists public reviews for one active product.
  Future<Map<String, Object?>> listProductReviews(
    String id,
    Map<String, String> parameters,
  ) async {
    _validateParameters(parameters, const {'page', 'limit'});
    final pagination = _parsePagination(parameters);
    final productId = _parseObjectId(id, 'product');
    final database = await _databaseProvider();
    final product = await database
        .collection(CollectionNames.products)
        .findOne(where.id(productId).eq('isActive', true).fields(['_id']));
    if (product == null) {
      throw const ApiException(
        statusCode: HttpStatus.notFound,
        code: 'product_not_found',
        message: 'Product not found.',
      );
    }

    final selector = where.eq('productId', productId);
    final reviewCollection = database.collection(CollectionNames.reviews);
    final total = await reviewCollection.count(selector);
    final pageSelector = where
        .eq('productId', productId)
        .sortBy('createdAt', descending: true)
        .skip(pagination.offset)
        .limit(pagination.limit);
    final documents = await reviewCollection.find(pageSelector).toList();
    return {
      'data': documents
          .map(Review.fromDocument)
          .map((item) => item.toJson())
          .toList(),
      'pagination': pagination.metadata(total),
    };
  }

  static SelectorBuilder _productSelector(
    CatalogQuery query,
    ObjectId? categoryId,
  ) {
    final selector = where.eq('isActive', true);
    if (categoryId != null) selector.eq('categoryId', categoryId);
    if (query.search != null) {
      selector.eq(r'$text', {r'$search': query.search});
    }
    if (query.minimumPriceMinor != null) {
      selector.gte('priceMinor', query.minimumPriceMinor);
    }
    if (query.maximumPriceMinor != null) {
      selector.lte('priceMinor', query.maximumPriceMinor);
    }
    if (query.inStockOnly) selector.gt('stock', 0);

    switch (query.sort) {
      case 'relevance':
        selector.sortByMetaTextScore('searchScore');
      case 'price_asc':
        selector.sortBy('priceMinor').sortBy('_id');
      case 'price_desc':
        selector.sortBy('priceMinor', descending: true).sortBy('_id');
      case 'name_asc':
        selector.sortBy('name').sortBy('_id');
      case 'rating_desc':
        selector.sortBy('averageRating', descending: true).sortBy('_id');
      case 'newest':
        selector.sortBy('createdAt', descending: true).sortBy('_id');
    }
    return selector;
  }

  static Pagination _parsePagination(Map<String, String> parameters) {
    try {
      return Pagination.parse(parameters);
    } on FormatException catch (error) {
      throw ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_query',
        message: error.message,
      );
    }
  }

  static CatalogQuery _parseCatalogQuery(Map<String, String> parameters) {
    try {
      return CatalogQuery.parse(parameters);
    } on FormatException catch (error) {
      throw ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_query',
        message: error.message,
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

  static void _validateParameters(
    Map<String, String> parameters,
    Set<String> supported,
  ) {
    final unknown = parameters.keys.toSet().difference(supported);
    if (unknown.isNotEmpty) {
      throw ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_query',
        message: 'Unsupported query parameter: ${unknown.first}.',
      );
    }
  }
}
