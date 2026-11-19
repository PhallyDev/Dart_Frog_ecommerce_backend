import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  return Response.json(
    body: const {
      'status': 'ok',
      'service': 'ShopEase Ecommerce API',
      'version': 'v1',
    },
  );
}
