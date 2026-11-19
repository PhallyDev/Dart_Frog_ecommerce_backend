import 'dart:convert';
import 'dart:io';

import 'package:shop_ease_ecommerce/application/ports/email_sender.dart';
import 'package:shop_ease_ecommerce/core/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/core/security/access_token_service.dart';
import 'package:shop_ease_ecommerce/core/security/password_hasher.dart';
import 'package:shop_ease_ecommerce/domain/entities/auth_identity.dart';
import 'package:shop_ease_ecommerce/domain/entities/auth_user.dart';
import 'package:shop_ease_ecommerce/domain/exceptions/account_already_exists.dart';
import 'package:shop_ease_ecommerce/domain/repositories/auth_repository.dart';

/// Provides auth persistence, with storage connection setup deferred per call.
typedef AuthRepositoryProvider = Future<AuthRepository> Function();

/// Authentication and password-recovery business logic.
class AuthService {
  /// Creates the service using injected storage, email, and password adapters.
  AuthService({
    required AuthRepositoryProvider repositoryProvider,
    required String jwtSecret,
    required EmailSender emailSender,
    PasswordHasher? passwordHasher,
    AccessTokenService? accessTokenService,
  }) : _repositoryProvider = repositoryProvider,
       _emailSender = emailSender,
       _passwordHasher = passwordHasher ?? PasswordHasher(),
       _accessTokenService =
           accessTokenService ?? AccessTokenService(jwtSecret);

  static const _verificationLifetime = Duration(minutes: 30);
  static const _passwordResetLifetime = Duration(minutes: 20);
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final AuthRepositoryProvider _repositoryProvider;
  final EmailSender _emailSender;
  final PasswordHasher _passwordHasher;
  final AccessTokenService _accessTokenService;

  /// Creates an account and emails a one-time email-verification token.
  Future<Map<String, Object?>> signUp(Map<String, Object?> body) async {
    _requireKeys(body, const {'email', 'password', 'displayName'});
    final email = _parseEmail(body['email']);
    final password = _parsePassword(body['password']);
    final displayName = _parseDisplayName(body['displayName']);
    final repository = await _repositoryProvider();
    if (await repository.findUserByEmail(email) != null) {
      throw const ApiException(
        statusCode: HttpStatus.conflict,
        code: 'email_already_registered',
        message: 'An account with this email already exists.',
      );
    }

    final token = _accessTokenService.generateOneTimeToken();
    final now = DateTime.now().toUtc();
    final passwordHash = await _passwordHasher.hash(password);
    String userId;
    try {
      userId = await repository.createUser(
        email: email,
        passwordHash: passwordHash,
        displayName: displayName,
        verificationTokenHash: AccessTokenService.hashOneTimeToken(token),
        verificationTokenExpiresAt: now.add(_verificationLifetime),
      );
    } on AccountAlreadyExists {
      throw const ApiException(
        statusCode: HttpStatus.conflict,
        code: 'email_already_registered',
        message: 'An account with this email already exists.',
      );
    }

    await _emailSender.sendVerification(email, token);
    return {
      'user': {
        'id': userId,
        'email': email,
        'displayName': displayName,
        'emailVerified': false,
      },
      'message': 'Check your email for a verification token.',
    };
  }

  /// Authenticates a verified account and creates a 15-minute session.
  Future<Map<String, Object?>> login(Map<String, Object?> body) async {
    _requireKeys(body, const {'email', 'password'});
    final email = _parseEmail(body['email']);
    final password = _parsePassword(body['password']);
    final repository = await _repositoryProvider();
    final credentials = await repository.findCredentialsByEmail(email);
    final user = credentials?.user;
    final passwordMatches = credentials != null
        ? await _passwordHasher.verify(password, credentials.passwordHash)
        : await _passwordHasher.hash(password).then((_) => false);
    if (user == null || !user.emailVerified || !passwordMatches) {
      throw const ApiException(
        statusCode: HttpStatus.unauthorized,
        code: 'invalid_credentials',
        message: 'Email or password is incorrect.',
      );
    }

    final sessionId = _accessTokenService.generateSessionId();
    final issued = _accessTokenService.issue(
      user.id,
      sessionId,
      credentialVersion: user.credentialVersion,
    );
    await repository.createSession(
      id: sessionId,
      userId: user.id,
      createdAt: DateTime.now().toUtc(),
      expiresAt: issued.expiresAt,
    );
    return {
      'accessToken': issued.value,
      'tokenType': 'Bearer',
      'expiresIn': _accessTokenService.lifetime.inSeconds,
      'user': _publicUser(user),
    };
  }

  /// Sends verification instructions without revealing account existence.
  Future<Map<String, Object?>> resendVerification(
    Map<String, Object?> body,
  ) async {
    _requireKeys(body, const {'email'});
    final email = _parseEmail(body['email']);
    final repository = await _repositoryProvider();
    final user = await repository.findUserByEmail(email);
    if (user != null && !user.emailVerified) {
      final token = _accessTokenService.generateOneTimeToken();
      await repository.updateVerificationToken(
        user.id,
        AccessTokenService.hashOneTimeToken(token),
        DateTime.now().toUtc().add(_verificationLifetime),
      );
      await _emailSender.sendVerification(email, token);
    }
    return {
      'message': 'If the account can be verified, instructions were sent.',
    };
  }

  /// Verifies and consumes a single-use email token.
  Future<Map<String, Object?>> verifyEmail(Map<String, Object?> body) async {
    _requireKeys(body, const {'token'});
    final token = _parseOneTimeToken(body['token']);
    final repository = await _repositoryProvider();
    final user = await repository.consumeVerificationToken(
      AccessTokenService.hashOneTimeToken(token),
      DateTime.now().toUtc(),
    );
    if (user == null) _throwInvalidOneTimeToken();
    return {
      'user': _publicUser(user),
      'message': 'Email address verified.',
    };
  }

  /// Sends a password-reset token with an account-enumeration-safe response.
  Future<Map<String, Object?>> forgotPassword(
    Map<String, Object?> body,
  ) async {
    _requireKeys(body, const {'email'});
    final email = _parseEmail(body['email']);
    final repository = await _repositoryProvider();
    final user = await repository.findUserByEmail(email);
    if (user != null) {
      final token = _accessTokenService.generateOneTimeToken();
      await repository.updatePasswordResetToken(
        email,
        AccessTokenService.hashOneTimeToken(token),
        DateTime.now().toUtc().add(_passwordResetLifetime),
      );
      await _emailSender.sendPasswordReset(email, token);
    }
    return {
      'message':
          'If an account exists for this email, reset instructions were sent.',
    };
  }

  /// Replaces the password and revokes every active session.
  Future<Map<String, Object?>> resetPassword(
    Map<String, Object?> body,
  ) async {
    _requireKeys(body, const {'token', 'password'});
    final token = _parseOneTimeToken(body['token']);
    final password = _parsePassword(body['password']);
    final repository = await _repositoryProvider();
    final passwordHash = await _passwordHasher.hash(password);
    final user = await repository.consumePasswordResetToken(
      AccessTokenService.hashOneTimeToken(token),
      passwordHash,
      DateTime.now().toUtc(),
    );
    if (user == null) _throwInvalidOneTimeToken();
    await repository.revokeAllSessions(user.id, DateTime.now().toUtc());
    return {'message': 'Password reset successfully. Please sign in again.'};
  }

  /// Validates a bearer token against its signed claims and active DB session.
  Future<AuthIdentity> authenticate(String authorization) async {
    final parts = authorization.trim().split(RegExp(r'\s+'));
    if (parts.length != 2 || parts.first.toLowerCase() != 'bearer') {
      _throwUnauthorized();
    }
    final claims = _accessTokenService.verify(parts.last);
    if (claims == null) _throwUnauthorized();

    final repository = await _repositoryProvider();
    final active = await repository.hasActiveSession(
      id: claims.sessionId,
      userId: claims.userId,
      now: DateTime.now().toUtc(),
    );
    final user = active ? await repository.findUserById(claims.userId) : null;
    if (!active ||
        user == null ||
        !user.emailVerified ||
        user.credentialVersion != claims.credentialVersion) {
      _throwUnauthorized();
    }
    return AuthIdentity(userId: claims.userId, sessionId: claims.sessionId);
  }

  /// Returns the public profile for the authenticated principal.
  Future<Map<String, Object?>> currentUser(AuthIdentity principal) async {
    final user = await (await _repositoryProvider()).findUserById(
      principal.userId,
    );
    if (user == null) _throwUnauthorized();
    return _publicUser(user);
  }

  /// Revokes only the caller's current login session.
  Future<void> logout(AuthIdentity principal) async {
    await (await _repositoryProvider()).revokeSession(
      principal.sessionId,
      principal.userId,
      DateTime.now().toUtc(),
    );
  }

  static void _requireKeys(
    Map<String, Object?> body,
    Set<String> allowed,
  ) {
    final unknown = body.keys.toSet().difference(allowed);
    if (unknown.isNotEmpty) {
      throw const ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_request',
        message: 'Request contains unsupported fields.',
      );
    }
    for (final key in allowed) {
      if (!body.containsKey(key)) {
        throw ApiException(
          statusCode: HttpStatus.badRequest,
          code: 'invalid_request',
          message: '$key is required.',
        );
      }
    }
  }

  static String _parseEmail(Object? value) {
    if (value is! String) _throwInvalidField('email');
    final email = value.trim().toLowerCase();
    if (email.length > 254 || !_emailPattern.hasMatch(email)) {
      _throwInvalidField('email');
    }
    return email;
  }

  static String _parsePassword(Object? value) {
    if (value is! String ||
        value.length < 12 ||
        value.length > 128 ||
        value.runes.length > 128 ||
        utf8.encode(value).length > 256) {
      _throwInvalidField(
        'password must contain 12–128 characters.',
      );
    }
    return value;
  }

  static String _parseDisplayName(Object? value) {
    if (value is! String) _throwInvalidField('displayName');
    final displayName = value.trim();
    if (displayName.length < 2 || displayName.length > 80) {
      _throwInvalidField('displayName');
    }
    return displayName;
  }

  static String _parseOneTimeToken(Object? value) {
    if (value is! String ||
        value.length < 32 ||
        value.length > 128 ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      _throwInvalidField('token');
    }
    return value;
  }

  static Map<String, Object?> _publicUser(AuthUser user) {
    return {
      'id': user.id,
      'email': user.email,
      'displayName': user.displayName,
      'emailVerified': user.emailVerified,
      if (user.phone != null) 'phone': user.phone,
    };
  }

  static Never _throwInvalidField(String field) {
    throw ApiException(
      statusCode: HttpStatus.badRequest,
      code: 'invalid_request',
      message: 'Invalid $field.',
    );
  }

  static Never _throwInvalidOneTimeToken() {
    throw const ApiException(
      statusCode: HttpStatus.badRequest,
      code: 'invalid_or_expired_token',
      message: 'The token is invalid or has expired.',
    );
  }

  static Never _throwUnauthorized() {
    throw const ApiException(
      statusCode: HttpStatus.unauthorized,
      code: 'unauthorized',
      message: 'Authentication is required or the session has expired.',
    );
  }
}
