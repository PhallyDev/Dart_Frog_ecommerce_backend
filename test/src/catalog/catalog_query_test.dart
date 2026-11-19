import 'package:shop_ease_ecommerce/src/catalog/catalog_query.dart';
import 'package:test/test.dart';

void main() {
  group('CatalogQuery.parse', () {
    test('converts price filters to minor currency units.', () {
      final query = CatalogQuery.parse({
        'q': 'lamp',
        'category': 'lighting',
        'sort': 'price_asc',
        'minPrice': '12.3',
        'maxPrice': '25.99',
        'inStock': 'true',
        'page': '2',
        'limit': '10',
      });

      expect(query.search, 'lamp');
      expect(query.categorySlug, 'lighting');
      expect(query.minimumPriceMinor, 1230);
      expect(query.maximumPriceMinor, 2599);
      expect(query.inStockOnly, isTrue);
      expect(query.pagination.page, 2);
      expect(query.pagination.limit, 10);
      expect(query.sort, 'price_asc');
    });

    test(
      'defaults text searches to relevance and unfiltered lists to newest.',
      () {
        expect(
          CatalogQuery.parse({'q': 'desk'}).sort,
          'relevance',
        );
        expect(
          CatalogQuery.parse(const {}).sort,
          'newest',
        );
      },
    );

    test('rejects unknown filters and unsupported sort options.', () {
      expect(
        () => CatalogQuery.parse({'filter': 'anything'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CatalogQuery.parse({'sort': 'random'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid price ranges and query types.', () {
      expect(
        () => CatalogQuery.parse({'minPrice': '4', 'maxPrice': '3'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CatalogQuery.parse({'minPrice': '1.999'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CatalogQuery.parse({'inStock': 'yes'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('bounds the query size and page size.', () {
      expect(
        () => CatalogQuery.parse({'q': 'a' * 101}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CatalogQuery.parse({'limit': '101'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
