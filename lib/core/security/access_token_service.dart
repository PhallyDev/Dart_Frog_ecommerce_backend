import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart'
    show Audience, JWT, JWTException, SecretKey;

/// Signed access token and its matching persistent session expiry.
class IssuedAccessToken {
  /// Creates an access token result.
  const IssuedAccessToken({required this.value, required this.expiresAt});

  /// Signed bearer token.
  final String value;

  /// UTC expiry time.
  final DateTime expiresAt;
}

/// Identity claims extracted from a verified access token.
class AccessTokenClaims {
  /// Creates verified claims for a session.
  const AccessTokenClaims({
    required this.userId,
    required this.sessionId,
    required this.credentialVersion,
  });

  /// Authenticated user's identifier.
  final String userId;

  /// Active login session identifier.
  final String sessionId;

  /// Credential generation used to revoke tokens after password changes.
  final int credentialVersion;
}

/// Issues short-lived signed access tokens and one-time random tokens.
class AccessTokenService {
  /// Creates a token service using a strong HMAC secret.
  AccessTokenService(
    this._secret, {
    this.lifetime = accessLifetime,
  }) : _random = Random.secure() {
    if (_secret.length < 32) {
      throw const FormatException('JWT_SECRET must be at least 32 characters.');
    }
    if (lifetime <= Duration.zero) {
      throw const FormatException(
        'JWT access-token lifetime must be positive.',
      );
    }
  }

  /// Default short-lived access-token lifetime.
  static const accessLifetime = Duration(minutes: 15);

  final String _secret;
  final Random _random;

  /// Configured lifetime for issued access tokens.
  final Duration lifetime;

  /// Creates a signed JWT bound to a user and revocable session ID.
  IssuedAccessToken issue(
    String userId,
    String sessionId, {
    required int credentialVersion,
  }) {
    if (!_isObjectId(userId) ||
        !_isObjectId(sessionId) ||
        credentialVersion < 0) {
      throw ArgumentError('JWT identity claims are invalid.');
    }
    final expiresAt = DateTime.now().toUtc().add(lifetime);
    final value = JWT(
      {'token_use': 'access', 'credential_version': credentialVersion},
      audience: Audience.one('shopease-api'),
      subject: userId,
      issuer: 'shopease-api',
      jwtId: sessionId,
    ).sign(SecretKey(_secret), expiresIn: lifetime);
    return IssuedAccessToken(value: value, expiresAt: expiresAt);
  }

  /// Verifies signature, algorithm constraints, issuer, audience, and claims.
  AccessTokenClaims? verify(String token) {
    try {
      final jwt = JWT.verify(
        token,
        SecretKey(_secret),
        issuer: 'shopease-api',
        audience: Audience.one('shopease-api'),
      );
      if (jwt.header?['alg'] != 'HS256') return null;
      final subject = jwt.subject;
      final sessionId = jwt.jwtId;
      final payload = jwt.payload;
      final credentialVersion = payload is Map
          ? payload['credential_version']
          : null;
      if (subject == null ||
          sessionId == null ||
          payload is! Map ||
          payload['token_use'] != 'access' ||
          payload['exp'] is! num ||
          credentialVersion is! num ||
          credentialVersion < 0 ||
          credentialVersion != credentialVersion.toInt() ||
          !_isObjectId(subject) ||
          !_isObjectId(sessionId)) {
        return null;
      }
      return AccessTokenClaims(
        userId: subject.toLowerCase(),
        sessionId: sessionId.toLowerCase(),
        credentialVersion: credentialVersion.toInt(),
      );
    } on JWTException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Generates an unpredictable URL-safe single-use token.
  String generateOneTimeToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Generates a 12-byte hexadecimal ID compatible with MongoDB ObjectIds.
  String generateSessionId() => List<int>.generate(
    12,
    (_) => _random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  /// Hashes a one-time token before it is stored in persistence.
  static String hashOneTimeToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  static bool _isObjectId(String value) =>
      RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value);
}
