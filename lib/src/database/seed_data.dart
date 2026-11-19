import 'package:mongo_dart/mongo_dart.dart';

/// Development-only catalog and checkout fixtures.
abstract final class SeedData {
  /// Stable category IDs used by the insert-only development fixtures.
  static final categoryIds = Map<String, ObjectId>.unmodifiable({
    'lighting': ObjectId.fromHexString('65b000000000000000000001'),
    'furniture': ObjectId.fromHexString('65b000000000000000000002'),
    'home-decor': ObjectId.fromHexString('65b000000000000000000003'),
  });

  /// Sample categories inserted by `dart run bin/seed.dart`.
  static final List<Map<String, Object?>> categories = [
    {
      '_id': categoryIds['lighting'],
      'name': 'Lighting',
      'slug': 'lighting',
      'description': 'Thoughtful lighting for work and home.',
      'sortOrder': 1,
      'isActive': true,
    },
    {
      '_id': categoryIds['furniture'],
      'name': 'Furniture',
      'slug': 'furniture',
      'description': 'Functional furniture for everyday spaces.',
      'sortOrder': 2,
      'isActive': true,
    },
    {
      '_id': categoryIds['home-decor'],
      'name': 'Home Decor',
      'slug': 'home-decor',
      'description': 'Finishing touches for a comfortable home.',
      'sortOrder': 3,
      'isActive': true,
    },
  ];

  static final List<Map<String, Object?>> _productDefinitions = [
    {
      '_id': ObjectId.fromHexString('65c000000000000000000001'),
      'name': 'Adjustable Desk Lamp',
      'slug': 'adjustable-desk-lamp',
      'sku': 'LMP-DESK-001',
      'description':
          'An adjustable LED desk lamp with a warm, focused reading light.',
      'categorySlug': 'lighting',
      'priceMinor': 4599,
      'currency': 'USD',
      'stock': 24,
      'isActive': true,
      'images': [
        {
          'url': 'https://images.example.test/adjustable-desk-lamp.jpg',
          'alt': 'Adjustable desk lamp',
          'sortOrder': 0,
        },
      ],
      'averageRating': 4.6,
      'reviewCount': 18,
    },
    {
      '_id': ObjectId.fromHexString('65c000000000000000000002'),
      'name': 'Oak Side Table',
      'slug': 'oak-side-table',
      'sku': 'FUR-SIDE-001',
      'description':
          'A compact oak-finish side table with a lower storage shelf.',
      'categorySlug': 'furniture',
      'priceMinor': 8999,
      'currency': 'USD',
      'stock': 12,
      'isActive': true,
      'images': [
        {
          'url': 'https://images.example.test/oak-side-table.jpg',
          'alt': 'Oak side table',
          'sortOrder': 0,
        },
      ],
      'averageRating': 4.8,
      'reviewCount': 11,
    },
    {
      '_id': ObjectId.fromHexString('65c000000000000000000003'),
      'name': 'Ceramic Table Vase',
      'slug': 'ceramic-table-vase',
      'sku': 'DEC-VASE-001',
      'description': 'A matte ceramic vase sized for shelves and side tables.',
      'categorySlug': 'home-decor',
      'priceMinor': 2499,
      'currency': 'USD',
      'stock': 18,
      'isActive': true,
      'images': [
        {
          'url': 'https://images.example.test/ceramic-table-vase.jpg',
          'alt': 'Ceramic table vase',
          'sortOrder': 0,
        },
      ],
      'averageRating': 4.4,
      'reviewCount': 7,
    },
  ];

  /// Builds product documents against the category IDs actually in MongoDB.
  static List<Map<String, Object?>> productsFor(
    Map<String, ObjectId> categoryIds,
  ) {
    return _productDefinitions
        .map((definition) {
          final categorySlug = definition['categorySlug'];
          if (categorySlug is! String || categoryIds[categorySlug] == null) {
            throw StateError('A product seed references a missing category.');
          }
          final product = Map<String, Object?>.from(definition)
            ..remove('categorySlug')
            ..['categoryId'] = categoryIds[categorySlug];
          return product;
        })
        .toList(growable: false);
  }

  /// Sample percent coupon for local checkout testing.
  static final List<Map<String, Object?>> coupons = [
    {
      '_id': ObjectId.fromHexString('65d000000000000000000001'),
      'code': 'WELCOME10',
      'kind': 'percent',
      'value': 10,
      'minimumSubtotalMinor': 2500,
      'usageLimit': 500,
      'usageCount': 0,
      'isActive': true,
    },
  ];

  /// Sample shipping options in USD.
  static final List<Map<String, Object?>> shippingMethods = [
    {
      '_id': ObjectId.fromHexString('65e000000000000000000001'),
      'code': 'standard',
      'name': 'Standard delivery',
      'priceMinor': 499,
      'currency': 'USD',
      'minimumDeliveryDays': 3,
      'maximumDeliveryDays': 5,
      'isActive': true,
    },
    {
      '_id': ObjectId.fromHexString('65e000000000000000000002'),
      'code': 'express',
      'name': 'Express delivery',
      'priceMinor': 1299,
      'currency': 'USD',
      'minimumDeliveryDays': 1,
      'maximumDeliveryDays': 2,
      'isActive': true,
    },
  ];
}
