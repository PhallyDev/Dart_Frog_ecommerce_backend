import 'package:shop_ease_ecommerce/src/auth/access_token_service.dart';
import 'package:test/test.dart';

void main() {
  test('issues and verifies an HS256 access token with required claims.', () {
    final service = AccessTokenService('a' * 64);
    const userId = '507f1f77bcf86cd799439011';
    const sessionId = '507f1f77bcf86cd799439012';
    final issued = service.issue(
      userId,
      sessionId,
      credentialVersion: 3,
    );

    final claims = service.verify(issued.value);

    expect(claims?.userId, userId);
    expect(claims?.sessionId, sessionId);
    expect(claims?.credentialVersion, 3);
    expect(issued.expiresAt.isAfter(DateTime.now().toUtc()), isTrue);
    expect(service.verify('${issued.value}tampered'), isNull);
  });

  test('rejects undersized signing secrets.', () {
    expect(
      () => AccessTokenService('too-short'),
      throwsA(isA<FormatException>()),
    );
  });

  test('uses the configured lifetime when issuing access tokens.', () {
    const lifetime = Duration(minutes: 30);
    final service = AccessTokenService('a' * 64, lifetime: lifetime);
    final before = DateTime.now().toUtc();

    final issued = service.issue(
      '507f1f77bcf86cd799439011',
      '507f1f77bcf86cd799439012',
      credentialVersion: 0,
    );

    expect(service.lifetime, lifetime);
    expect(
      issued.expiresAt.difference(before),
      greaterThanOrEqualTo(lifetime),
    );
  });

  test('hashes one-time tokens before persistence.', () {
    final hash = AccessTokenService.hashOneTimeToken('sensitive-token');

    expect(hash, isNot('sensitive-token'));
    expect(hash, hasLength(64));
  });
}
