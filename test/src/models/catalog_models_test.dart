import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/models/category.dart';
import 'package:shop_ease_ecommerce/src/models/product.dart';
import 'package:shop_ease_ecommerce/src/models/review.dart';
import 'package:test/test.dart';

void main() {
  final id = ObjectId.fromHexString('507f1f77bcf86cd799439011');

  test('serializes category IDs without exposing BSON values.', () {
    final category = Category.fromDocument({
      '_id': id,
      'name': 'Lighting',
      'slug': 'lighting',
      'sortOrder': 1,
      'isActive': true,
    });

    expect(category.toJson(), {
      'id': id.oid,
      'name': 'Lighting',
      'slug': 'lighting',
      'sortOrder': 1,
    });
  });

  test('validates product image metadata and public product fields.', () {
    final product = Product.fromDocument({
      '_id': id,
      'name': 'Desk lamp',
      'slug': 'desk-lamp',
      'description': 'A lamp.',
      'categoryId': id,
      'priceMinor': 4599,
      'currency': 'USD',
      'stock': 3,
      'images': [
        {'url': 'https://cdn.example.test/lamp.png', 'sortOrder': 0},
      ],
      'internalCostMinor': 1000,
    });

    expect(product.toJson()['id'], id.oid);
    expect(product.toJson().containsKey('internalCostMinor'), isFalse);
    expect(
      Product.parseImages([
        {'url': 'https://cdn.example.test/lamp.png'},
      ]),
      [
        {'url': 'https://cdn.example.test/lamp.png'},
      ],
    );
    expect(
      () => Product.parseImages([
        {'url': 42},
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  test('review JSON never exposes internal user or product references.', () {
    final review = Review.fromDocument({
      '_id': id,
      'userId': id,
      'productId': id,
      'rating': 5,
      'reviewerName': 'Customer',
      'createdAt': DateTime.utc(2026, 10, 27),
    });

    expect(review.toJson(), {
      'id': id.oid,
      'rating': 5,
      'reviewerName': 'Customer',
      'createdAt': '2026-10-27T00:00:00.000Z',
    });
  });
}
