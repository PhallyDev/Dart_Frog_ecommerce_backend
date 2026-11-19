import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/catalog/catalog_service.dart';
import 'package:shop_ease_ecommerce/src/http/query_parameters.dart';

Future<Response> onRequest(RequestContext context) async {
  requireGet(context.request.method.value);
  final parameters = singleQueryParameters(
    context.request.uri.queryParametersAll,
  );
  final result = await context.read<CatalogService>().listProducts(parameters);
  return Response.json(body: result);
}
