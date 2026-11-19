/// Public account data returned by authentication persistence operations.
class AuthUser {
  /// Creates public account data required by authentication operations.
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.credentialVersion,
    this.phone,
  });

  /// Stable account identifier represented without persistence-specific types.
  final String id;

  /// Normalized account email.
  final String email;

  /// User's display name.
  final String displayName;

  /// Whether the account has completed email verification.
  final bool emailVerified;

  /// Credential generation used to invalidate older access tokens.
  final int credentialVersion;

  /// Optional public phone number.
  final String? phone;
}

/// Password credential paired with its public account data for login checks.
class AuthCredentials {
  /// Creates credentials for a password verification operation.
  const AuthCredentials({required this.user, required this.passwordHash});

  /// Public account information.
  final AuthUser user;

  /// Encoded password hash; never returned to API consumers.
  final String passwordHash;
}
