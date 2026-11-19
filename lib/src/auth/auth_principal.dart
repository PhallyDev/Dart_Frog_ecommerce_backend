import 'package:mongo_dart/mongo_dart.dart';

/// Authenticated user and revocable session established by middleware.
class AuthPrincipal {
  /// Creates an authenticated principal.
  const AuthPrincipal({required this.userId, required this.sessionId});

  /// User account ObjectId.
  final ObjectId userId;

  /// Active login session ObjectId.
  final ObjectId sessionId;
}
