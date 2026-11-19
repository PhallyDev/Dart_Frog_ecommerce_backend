/// Authenticated account and session identifiers from verified token claims.
class AuthIdentity {
  /// Creates an identity from verified token claims.
  const AuthIdentity({required this.userId, required this.sessionId});

  /// Authenticated account identifier.
  final String userId;

  /// Active authenticated session identifier.
  final String sessionId;
}
