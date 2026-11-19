import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shop_ease_ecommerce/src/catalog/catalog_service.dart';
import 'package:test/test.dart';

import '../../../../../routes/api/v1/categories/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockCatalogService extends Mock implements CatalogService {}

void main() {
  test('returns the paginated category service response as JSON.', () async {
    final context = _MockRequestContext();
    final service = _MockCatalogService();
    when(() => context.request).thenReturn(
      Request.get(
        Uri.parse('http://localhost/api/v1/categories?page=2&limit=5'),
      ),
    );
    when(() => context.read<CatalogService>()).thenReturn(service);
    when(() => service.listCategories({'page': '2', 'limit': '5'})).thenAnswer(
      (_) async => {
        'data': [
          {'id': '507f1f77bcf86cd799439011', 'slug': 'lighting'},
        ],
        'pagination': {'page': 2, 'limit': 5, 'total': 6, 'totalPages': 2},
      },
    );

    final response = await route.onRequest(context);
    final body = jsonDecode(await response.body()) as Map<String, dynamic>;

    expect(response.statusCode, 200);
    expect(body['pagination'], {
      'page': 2,
      'limit': 5,
      'total': 6,
      'totalPages': 2,
    });
    verify(() => service.listCategories({'page': '2', 'limit': '5'})).called(1);
  });
}
