import 'package:shop_ease_ecommerce/application/ports/email_sender.dart';
import 'package:shop_ease_ecommerce/application/use_cases/auth/auth_service.dart';
import 'package:shop_ease_ecommerce/core/security/access_token_service.dart';
import 'package:shop_ease_ecommerce/core/security/password_hasher.dart';
import 'package:shop_ease_ecommerce/domain/entities/auth_user.dart';
import 'package:shop_ease_ecommerce/domain/repositories/auth_repository.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:test/test.dart';

class _MemoryAuthRepository implements AuthRepository {
  AuthUser? user;
  AuthCredentials? credentials;
  String? createdPasswordHash;
  int sessionsCreated = 0;
  bool activeSession = true;

  @override
  Future<AuthUser?> findUserByEmail(String email) async => user;

  @override
  Future<AuthCredentials?> findCredentialsByEmail(String email) async =>
      credentials;

  @override
  Future<AuthUser?> findUserById(String id) async =>
      user?.id == id ? user : null;

  @override
  Future<String> createUser({
    required String email,
    required String passwordHash,
    required String displayName,
    required String verificationTokenHash,
    required DateTime verificationTokenExpiresAt,
  }) async {
    createdPasswordHash = passwordHash;
    user = _user(email: email);
    return user!.id;
  }

  @override
  Future<void> createSession({
    required String id,
    required String userId,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) async {
    sessionsCreated++;
  }

  @override
  Future<bool> hasActiveSession({
    required String id,
    required String userId,
    required DateTime now,
  }) async => activeSession;

  @override
  Future<void> revokeSession(
    String id,
    String userId,
    DateTime revokedAt,
  ) async {}

  @override
  Future<void> revokeAllSessions(String userId, DateTime revokedAt) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryEmailSender implements EmailSender {
  final verificationTokens = <String>[];

  @override
  Future<void> sendPasswordReset(String email, String token) async {}

  @override
  Future<void> sendVerification(String email, String token) async {
    verificationTokens.add(token);
  }
}

class _TestPasswordHasher extends PasswordHasher {
  @override
  Future<String> hash(String password) async => 'encoded:$password';

  @override
  Future<bool> verify(String password, String encodedHash) async =>
      encodedHash == 'encoded:correct-password' &&
      password == 'correct-password';
}

AuthUser _user({
  String id = '507f1f77bcf86cd799439011',
  String email = 'customer@example.test',
  bool emailVerified = true,
}) => AuthUser(
  id: id,
  email: email,
  displayName: 'Customer',
  emailVerified: emailVerified,
  credentialVersion: 0,
);

void main() {
  late _MemoryAuthRepository repository;
  late _MemoryEmailSender emailSender;
  late AccessTokenService tokenService;
  late AuthService service;

  setUp(() {
    repository = _MemoryAuthRepository();
    emailSender = _MemoryEmailSender();
    tokenService = AccessTokenService('a' * 64);
    service = AuthService(
      repositoryProvider: () async => repository,
      jwtSecret: 'a' * 64,
      emailSender: emailSender,
      passwordHasher: _TestPasswordHasher(),
      accessTokenService: tokenService,
    );
  });

  test(
    'registration stores a hash and returns no credential material.',
    () async {
      final response = await service.signUp({
        'email': 'Customer@Example.Test',
        'password': 'correct-password',
        'displayName': 'Customer',
      });

      expect(repository.createdPasswordHash, 'encoded:correct-password');
      expect(repository.createdPasswordHash, isNot('correct-password'));
      expect(emailSender.verificationTokens, hasLength(1));
      expect(response['user'], {
        'id': repository.user!.id,
        'email': 'customer@example.test',
        'displayName': 'Customer',
        'emailVerified': false,
      });
      expect(response.toString(), isNot(contains('passwordHash')));
    },
  );

  test('login issues a token and exposes only public user data.', () async {
    repository.user = _user();
    repository.credentials = AuthCredentials(
      user: repository.user!,
      passwordHash: 'encoded:correct-password',
    );

    final response = await service.login({
      'email': 'customer@example.test',
      'password': 'correct-password',
    });
    final user = response['user']! as Map<String, Object?>;
    final claims = tokenService.verify(response['accessToken']! as String);

    expect(response['tokenType'], 'Bearer');
    expect(response['expiresIn'], const Duration(minutes: 15).inSeconds);
    expect(claims?.userId, repository.user!.id);
    expect(user, {
      'id': repository.user!.id,
      'email': repository.user!.email,
      'displayName': repository.user!.displayName,
      'emailVerified': true,
    });
    expect(user.containsKey('passwordHash'), isFalse);
    expect(repository.sessionsCreated, 1);
  });

  test(
    'incorrect password and nonexistent user share the same 401 error.',
    () async {
      repository.user = _user();
      repository.credentials = AuthCredentials(
        user: repository.user!,
        passwordHash: 'encoded:correct-password',
      );

      await expectLater(
        service.login({
          'email': 'customer@example.test',
          'password': 'incorrect-password',
        }),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );

      repository.credentials = null;

      await expectLater(
        service.login({
          'email': 'unknown@example.test',
          'password': 'correct-password',
        }),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
    },
  );

  test('rejects invalid and expired bearer tokens.', () async {
    await expectLater(
      service.authenticate('Bearer invalid'),
      throwsA(isA<ApiException>()),
    );

    final shortLivedTokenService = AccessTokenService(
      'a' * 64,
      lifetime: const Duration(seconds: 1),
    );
    final issued = shortLivedTokenService.issue(
      '507f1f77bcf86cd799439011',
      '507f1f77bcf86cd799439012',
      credentialVersion: 0,
    );
    final expiringService = AuthService(
      repositoryProvider: () async => repository,
      jwtSecret: 'a' * 64,
      emailSender: emailSender,
      passwordHasher: _TestPasswordHasher(),
      accessTokenService: shortLivedTokenService,
    );
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    await expectLater(
      expiringService.authenticate('Bearer ${issued.value}'),
      throwsA(isA<ApiException>()),
    );
  });
}
