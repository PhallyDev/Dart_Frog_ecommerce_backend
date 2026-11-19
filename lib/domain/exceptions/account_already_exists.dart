/// Indicates that an account already exists for a unique registration key.
class AccountAlreadyExists implements Exception {
  /// Creates the unique-account conflict exception.
  const AccountAlreadyExists();
}
