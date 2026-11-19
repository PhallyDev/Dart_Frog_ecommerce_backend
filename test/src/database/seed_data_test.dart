import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/database/seed_data.dart';
import 'package:test/test.dart';

void main() {
  test('seed identifiers and unique public keys are consistent.', () {
    final products = SeedData.productsFor(SeedData.categoryIds);
    final categoryIds = SeedData.categories
        .map((category) => category['_id'])
        .whereType<ObjectId>()
        .toSet();
    final slugs = products.map((product) => product['slug']).toSet();

    expect(categoryIds, hasLength(3));
    expect(SeedData.categories, hasLength(3));
    expect(products, hasLength(3));
    expect(slugs, hasLength(3));
    expect(
      products.every(
        (product) => categoryIds.contains(product['categoryId']),
      ),
      isTrue,
    );
    expect(
      products.every(
        (product) =>
            product['priceMinor'] is int &&
            product['stock'] is int &&
            product['currency'] == 'USD',
      ),
      isTrue,
    );

    expect(
      () => SeedData.productsFor(const {}),
      throwsA(isA<StateError>()),
    );
  });

  test('checkout fixtures use valid codes.', () {
    expect(SeedData.coupons.single['code'], 'WELCOME10');
    expect(
      SeedData.shippingMethods.map((method) => method['code']).toSet(),
      {'standard', 'express'},
    );
  });
}
