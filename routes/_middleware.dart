import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/errors/api_error_response.dart';

Handler middleware(Handler handler) {
  return (context) async {
    try {
      return await handler(context);
    } catch (error, stackTrace) {
      return apiErrorResponse(error, stackTrace);
    }
  };
}
