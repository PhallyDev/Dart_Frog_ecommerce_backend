import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/catalog/catalog_service.dart';
import 'package:shop_ease_ecommerce/src/http/query_parameters.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  requireGet(context.request.method.value);
  final result = await context.read<CatalogService>().getProduct(
    id,
  );
  return Response.json(body: result);
}
