import 'package:shop_ease_ecommerce/domain/entities/auth_user.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_repository.dart';
import 'package:shop_ease_ecommerce/src/auth/auth_service.dart';
import 'package:shop_ease_ecommerce/src/auth/email_sender.dart';
import 'package:test/test.dart';

class _RecordingRepository implements AuthRepository {
  AuthUser? user;
  var _verificationUpdates = 0;
  var _passwordResetUpdates = 0;

  @override
  Future<AuthUser?> findUserByEmail(String email) async => user;

  @override
  Future<void> updateVerificationToken(
    String userId,
    String tokenHash,
    DateTime expiresAt,
  ) async {
    _verificationUpdates++;
  }

  @override
  Future<void> updatePasswordResetToken(
    String email,
    String tokenHash,
    DateTime expiresAt,
  ) async {
    _passwordResetUpdates++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingEmailSender implements EmailSender {
  final verificationRecipients = <String>[];
  final resetRecipients = <String>[];

  @override
  Future<void> sendPasswordReset(String email, String token) async {
    resetRecipients.add(email);
  }

  @override
  Future<void> sendVerification(String email, String token) async {
    verificationRecipients.add(email);
  }
}

void main() {
  late _RecordingRepository repository;
  late _RecordingEmailSender emailSender;
  late AuthService service;

  setUp(() {
    repository = _RecordingRepository();
    emailSender = _RecordingEmailSender();
    service = AuthService(
      repositoryProvider: () async => repository,
      jwtSecret: 'a' * 64,
      emailSender: emailSender,
    );
  });

  test('does not send recovery email for an unknown account', () async {
    final response = await service.forgotPassword({
      'email': 'customer@example.test',
    });

    expect(response['message'], contains('If an account exists'));
    expect(emailSender.resetRecipients, isEmpty);
    expect(repository._passwordResetUpdates, 0);
  });

  test('sends recovery email for an existing account', () async {
    repository.user = _user();

    await service.forgotPassword({'email': 'customer@example.test'});

    expect(emailSender.resetRecipients, ['customer@example.test']);
    expect(repository._passwordResetUpdates, 1);
  });

  test('does not send verification email for an unknown account', () async {
    final response = await service.resendVerification({
      'email': 'customer@example.test',
    });

    expect(response['message'], contains('If the account can be verified'));
    expect(emailSender.verificationRecipients, isEmpty);
    expect(repository._verificationUpdates, 0);
  });

  test('sends verification email for an unverified account', () async {
    repository.user = _user();

    await service.resendVerification({'email': 'customer@example.test'});

    expect(emailSender.verificationRecipients, ['customer@example.test']);
    expect(repository._verificationUpdates, 1);
  });

  test('does not resend verification email for a verified account', () async {
    repository.user = _user(emailVerified: true);

    await service.resendVerification({'email': 'customer@example.test'});

    expect(emailSender.verificationRecipients, isEmpty);
    expect(repository._verificationUpdates, 0);
  });
}

AuthUser _user({bool emailVerified = false}) => AuthUser(
  id: '0123456789abcdef01234567',
  email: 'customer@example.test',
  displayName: 'Customer',
  emailVerified: emailVerified,
  credentialVersion: 0,
);
