import 'package:shop_ease_ecommerce/src/auth/auth_service.dart';
import 'package:shop_ease_ecommerce/src/auth/email_sender.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:test/test.dart';

class _UnusedEmailSender implements EmailSender {
  @override
  Future<void> sendPasswordReset(String email, String token) async {}

  @override
  Future<void> sendVerification(String email, String token) async {}
}

void main() {
  late AuthService service;

  setUp(() {
    service = AuthService(
      repositoryProvider: () => throw StateError(
        'Invalid requests must be rejected before connecting to MongoDB.',
      ),
      jwtSecret: 'a' * 64,
      emailSender: _UnusedEmailSender(),
    );
  });

  test('rejects invalid signup email before connecting to MongoDB.', () async {
    await expectLater(
      service.signUp({
        'email': 'not-an-email',
        'password': 'a-long-enough-password',
        'displayName': 'Customer',
      }),
      throwsA(isA<ApiException>()),
    );
  });

  test('rejects passwords that do not meet the minimum length.', () async {
    await expectLater(
      service.login({'email': 'customer@example.test', 'password': 'short'}),
      throwsA(isA<ApiException>()),
    );
  });

  test('rejects unsupported request fields.', () async {
    await expectLater(
      service.forgotPassword({
        'email': 'customer@example.test',
        'admin': true,
      }),
      throwsA(isA<ApiException>()),
    );
  });
}
