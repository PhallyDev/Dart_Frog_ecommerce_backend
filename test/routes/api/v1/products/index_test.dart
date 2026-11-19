import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shop_ease_ecommerce/src/catalog/catalog_service.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:test/test.dart';

import '../../../../../routes/api/v1/products/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockCatalogService extends Mock implements CatalogService {}

void main() {
  test(
    'forwards product filters and returns the paginated JSON response.',
    () async {
      final context = _MockRequestContext();
      final service = _MockCatalogService();
      const parameters = {
        'q': 'lamp',
        'category': 'lighting',
        'sort': 'price_asc',
        'page': '1',
        'limit': '20',
      };
      when(() => context.request).thenReturn(
        Request.get(
          Uri.parse(
            'http://localhost/api/v1/products?q=lamp&category=lighting'
            '&sort=price_asc&page=1&limit=20',
          ),
        ),
      );
      when(() => context.read<CatalogService>()).thenReturn(service);
      when(() => service.listProducts(parameters)).thenAnswer(
        (_) async => {
          'data': [
            {'id': '507f1f77bcf86cd799439011', 'name': 'Desk lamp'},
          ],
          'pagination': {'page': 1, 'limit': 20, 'total': 1, 'totalPages': 1},
        },
      );

      final response = await route.onRequest(context);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;

      expect(response.statusCode, 200);
      expect(body['data'], [
        {'id': '507f1f77bcf86cd799439011', 'name': 'Desk lamp'},
      ]);
      verify(() => service.listProducts(parameters)).called(1);
    },
  );

  test('rejects repeated query keys before calling the service.', () async {
    final context = _MockRequestContext();
    when(() => context.request).thenReturn(
      Request.get(
        Uri.parse('http://localhost/api/v1/products?page=1&page=2'),
      ),
    );

    await expectLater(
      route.onRequest(context),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'invalid_query',
        ),
      ),
    );
    verifyNever(() => context.read<CatalogService>());
  });
}
