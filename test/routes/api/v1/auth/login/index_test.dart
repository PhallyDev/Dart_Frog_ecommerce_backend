import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shop_ease_ecommerce/application/use_cases/auth/auth_service.dart';
import 'package:test/test.dart';

import '../../../../../../routes/api/v1/auth/login/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  test(
    'returns the login envelope and preserves legacy top-level fields.',
    () async {
      final context = _MockRequestContext();
      final service = _MockAuthService();
      const requestBody = {
        'email': 'customer@example.test',
        'password': 'a-long-enough-password',
      };
      final serviceResponse = {
        'accessToken': 'signed-token',
        'tokenType': 'Bearer',
        'expiresIn': 900,
        'user': {
          'id': '507f1f77bcf86cd799439011',
          'email': 'customer@example.test',
          'displayName': 'ShopEase Customer',
          'emailVerified': true,
        },
      };
      when(() => context.request).thenReturn(
        Request.post(
          Uri.parse('http://localhost/api/v1/auth/login'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(requestBody),
        ),
      );
      when(() => context.read<AuthService>()).thenReturn(service);
      when(
        () => service.login(requestBody),
      ).thenAnswer((_) async => serviceResponse);

      final response = await route.onRequest(context);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;

      expect(response.statusCode, 200);
      expect(body['success'], isTrue);
      expect(body['message'], 'Login successful');
      expect(data['accessToken'], 'signed-token');
      expect(
        (data['user'] as Map<String, dynamic>)['name'],
        'ShopEase Customer',
      );
      expect(body['accessToken'], 'signed-token');
      verify(() => service.login(requestBody)).called(1);
    },
  );
}
