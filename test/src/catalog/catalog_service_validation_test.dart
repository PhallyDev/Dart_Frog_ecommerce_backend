import 'package:shop_ease_ecommerce/src/catalog/catalog_service.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:test/test.dart';

void main() {
  test('rejects invalid filters before opening MongoDB.', () async {
    var connectionRequests = 0;
    final service = CatalogService.fromProvider(() {
      connectionRequests++;
      throw StateError('MongoDB must not be accessed for invalid input.');
    });

    await expectLater(
      service.listProducts({'limit': '101'}),
      throwsA(isA<ApiException>()),
    );
    expect(connectionRequests, 0);
  });

  test('rejects malformed product IDs before opening MongoDB.', () async {
    var connectionRequests = 0;
    final service = CatalogService.fromProvider(() {
      connectionRequests++;
      throw StateError('MongoDB must not be accessed for invalid input.');
    });

    await expectLater(
      service.getProduct('not-an-object-id'),
      throwsA(isA<ApiException>()),
    );
    expect(connectionRequests, 0);
  });
}
