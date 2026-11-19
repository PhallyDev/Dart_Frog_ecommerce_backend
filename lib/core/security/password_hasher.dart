import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Argon2id password hashing using OWASP's recommended baseline parameters.
class PasswordHasher {
  /// Creates a password hasher with secure random salts.
  PasswordHasher({Random? random})
    : _random = random ?? Random.secure(),
      _algorithm = Argon2id(
        parallelism: 1,
        memory: 19456,
        iterations: 2,
        hashLength: 32,
      );

  final Random _random;
  final Argon2id _algorithm;

  /// Hashes a password with a fresh 128-bit random salt.
  Future<String> hash(String password) async {
    final salt = _randomBytes(16);
    final key = await _algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final hash = await key.extractBytes();
    return r'argon2id$v=19$m=19456,t=2,p=1$'
        '${base64Url.encode(salt).replaceAll('=', '')}\$'
        '${base64Url.encode(hash).replaceAll('=', '')}';
  }

  /// Verifies an encoded Argon2id password hash without early byte exits.
  Future<bool> verify(String password, String encodedHash) async {
    final parts = encodedHash.split(r'$');
    if (parts.length != 5 ||
        parts[0] != 'argon2id' ||
        parts[1] != 'v=19' ||
        parts[2] != 'm=19456,t=2,p=1') {
      return false;
    }

    try {
      final salt = _decodeBase64Url(parts[3]);
      final expected = _decodeBase64Url(parts[4]);
      if (salt.length != 16 || expected.length != 32) return false;
      final derived = await _algorithm.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );
      final actual = await derived.extractBytes();
      return _constantTimeEquals(actual, expected);
    } on FormatException {
      return false;
    }
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));

  static List<int> _decodeBase64Url(String value) {
    final remainder = value.length % 4;
    final padded = remainder == 0
        ? value
        : value.padRight(value.length + 4 - remainder, '=');
    return base64Url.decode(padded);
  }

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}
