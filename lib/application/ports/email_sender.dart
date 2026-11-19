/// Delivers one-time authentication tokens outside of API responses.
abstract interface class EmailSender {
  /// Sends an email-verification token.
  Future<void> sendVerification(String email, String token);

  /// Sends a password-reset token.
  Future<void> sendPasswordReset(String email, String token);
}
