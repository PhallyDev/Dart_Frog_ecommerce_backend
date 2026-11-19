import 'package:shop_ease_ecommerce/domain/entities/auth_user.dart';

/// Persistence contract required by authentication use cases.
abstract interface class AuthRepository {
  /// Finds public account data by normalized email.
  Future<AuthUser?> findUserByEmail(String email);

  /// Finds account data and its private password hash for login.
  Future<AuthCredentials?> findCredentialsByEmail(String email);

  /// Finds public account data by stable account ID.
  Future<AuthUser?> findUserById(String id);

  /// Creates an unverified account and returns its stable ID.
  Future<String> createUser({
    required String email,
    required String passwordHash,
    required String displayName,
    required String verificationTokenHash,
    required DateTime verificationTokenExpiresAt,
  });

  /// Replaces the pending email-verification token.
  Future<void> updateVerificationToken(
    String userId,
    String tokenHash,
    DateTime expiresAt,
  );

  /// Atomically verifies and consumes a valid email token.
  Future<AuthUser?> consumeVerificationToken(String tokenHash, DateTime now);

  /// Stores a hashed, expiring password-reset token for an existing account.
  Future<void> updatePasswordResetToken(
    String email,
    String tokenHash,
    DateTime expiresAt,
  );

  /// Consumes a valid reset token and updates the password hash.
  Future<AuthUser?> consumePasswordResetToken(
    String tokenHash,
    String passwordHash,
    DateTime now,
  );

  /// Creates a revocable access-token session.
  Future<void> createSession({
    required String id,
    required String userId,
    required DateTime createdAt,
    required DateTime expiresAt,
  });

  /// Checks whether a session is still active for the account.
  Future<bool> hasActiveSession({
    required String id,
    required String userId,
    required DateTime now,
  });

  /// Revokes one account's session.
  Future<void> revokeSession(String id, String userId, DateTime revokedAt);

  /// Revokes every active session belonging to an account.
  Future<void> revokeAllSessions(String userId, DateTime revokedAt);
}
