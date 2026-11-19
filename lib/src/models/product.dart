import 'package:mongo_dart/mongo_dart.dart';

/// Public product data returned by catalog endpoints.
class Product {
  /// Creates a product response model.
  const Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.categoryId,
    required this.priceMinor,
    required this.currency,
    required this.stock,
    required this.images,
    this.sku,
    this.averageRating,
    this.reviewCount,
  });

  /// Reads and validates a product document from MongoDB.
  factory Product.fromDocument(Map<String, dynamic> document) {
    final id = document['_id'];
    final name = document['name'];
    final slug = document['slug'];
    final description = document['description'];
    final categoryId = document['categoryId'];
    final priceMinor = document['priceMinor'];
    final currency = document['currency'];
    final stock = document['stock'];
    final rawImages = document['images'];
    if (id is! ObjectId ||
        name is! String ||
        slug is! String ||
        description is! String ||
        categoryId is! ObjectId ||
        priceMinor is! num ||
        currency is! String ||
        stock is! num ||
        rawImages is! List) {
      throw const FormatException('Invalid product document.');
    }
    if (priceMinor < 0 ||
        stock < 0 ||
        priceMinor != priceMinor.toInt() ||
        stock != stock.toInt() ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const FormatException('Invalid product price, currency, or stock.');
    }
    final images = parseImages(rawImages);

    return Product(
      id: id,
      name: name,
      slug: slug,
      description: description,
      categoryId: categoryId,
      priceMinor: priceMinor.toInt(),
      currency: currency,
      stock: stock.toInt(),
      images: images,
      sku: document['sku'] as String?,
      averageRating: (document['averageRating'] as num?)?.toDouble(),
      reviewCount: (document['reviewCount'] as num?)?.toInt(),
    );
  }

  /// Validates and returns public image metadata from a product document.
  static List<Map<String, Object?>> parseImages(Object? rawImages) {
    if (rawImages is! List) {
      throw const FormatException('Invalid product images.');
    }
    return rawImages
        .map((image) {
          if (image is! Map) {
            throw const FormatException('Invalid product image metadata.');
          }
          final url = image['url'];
          if (url is! String) {
            throw const FormatException('Product image URL is required.');
          }
          return <String, Object?>{
            'url': url,
            if (image['alt'] is String) 'alt': image['alt'],
            if (image['sortOrder'] is num)
              'sortOrder': (image['sortOrder'] as num).toInt(),
          };
        })
        .toList(growable: false);
  }

  /// MongoDB product identifier as a hex string.
  final ObjectId id;

  /// Product display name.
  final String name;

  /// URL-safe product slug.
  final String slug;

  /// Product description.
  final String description;

  /// Referenced category identifier.
  final ObjectId categoryId;

  /// Unit price in minor currency units.
  final int priceMinor;

  /// ISO 4217 currency code.
  final String currency;

  /// Current available inventory.
  final int stock;

  /// Optional stock keeping unit.
  final String? sku;

  /// Public image metadata.
  final List<Map<String, Object?>> images;

  /// Optional denormalized average rating.
  final double? averageRating;

  /// Optional denormalized review count.
  final int? reviewCount;

  /// Converts the product into an API-safe JSON object.
  Map<String, Object?> toJson({bool includeImages = true}) => {
    'id': id.oid,
    'name': name,
    'slug': slug,
    'description': description,
    'categoryId': categoryId.oid,
    'priceMinor': priceMinor,
    'currency': currency,
    'stock': stock,
    if (sku != null) 'sku': sku,
    if (includeImages) 'images': images,
    if (averageRating != null) 'averageRating': averageRating,
    if (reviewCount != null) 'reviewCount': reviewCount,
  };
}
