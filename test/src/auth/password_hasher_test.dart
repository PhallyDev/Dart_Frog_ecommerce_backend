import 'package:shop_ease_ecommerce/src/auth/password_hasher.dart';
import 'package:test/test.dart';

void main() {
  test('hashes passwords with unique salts and verifies them.', () async {
    final hasher = PasswordHasher();
    const password = 'correct horse battery staple';

    final firstHash = await hasher.hash(password);
    final secondHash = await hasher.hash(password);

    expect(firstHash, startsWith(r'argon2id$v=19$m=19456,t=2,p=1$'));
    expect(firstHash, isNot(contains(password)));
    expect(firstHash, isNot(secondHash));
    expect(await hasher.verify(password, firstHash), isTrue);
    expect(await hasher.verify('incorrect password', firstHash), isFalse);
    expect(await hasher.verify(password, 'invalid-hash'), isFalse);
  });
}
