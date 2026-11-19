import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_middleware.dart';

Handler middleware(Handler handler) => requireAuthenticatedUser(handler);
