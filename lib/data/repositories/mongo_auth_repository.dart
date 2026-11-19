import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/domain/entities/auth_user.dart';
import 'package:shop_ease_ecommerce/domain/exceptions/account_already_exists.dart';
import 'package:shop_ease_ecommerce/domain/repositories/auth_repository.dart';
import 'package:shop_ease_ecommerce/src/database/collection_names.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database.dart';

/// MongoDB adapter for the domain authentication repository contract.
class MongoAuthRepository implements AuthRepository {
  /// Creates a repository using the shared database connection.
  const MongoAuthRepository(this._database);

  final MongoDatabase _database;

  DbCollection get _users => _database.collection(CollectionNames.users);

  DbCollection get _sessions =>
      _database.collection(CollectionNames.userSessions);

  @override
  Future<AuthUser?> findUserByEmail(String email) async {
    final document = await _users.findOne(where.eq('email', email));
    return document == null ? null : _mapUser(document);
  }

  @override
  Future<AuthCredentials?> findCredentialsByEmail(String email) async {
    final document = await _users.findOne(where.eq('email', email));
    if (document == null) return null;
    final passwordHash = document['passwordHash'];
    if (passwordHash is! String || passwordHash.isEmpty) {
      throw StateError('User record is missing its password hash.');
    }
    return AuthCredentials(
      user: _mapUser(document),
      passwordHash: passwordHash,
    );
  }

  @override
  Future<AuthUser?> findUserById(String id) async {
    final document = await _users.findOne(where.id(_objectId(id)));
    return document == null ? null : _mapUser(document);
  }

  @override
  Future<String> createUser({
    required String email,
    required String passwordHash,
    required String displayName,
    required String verificationTokenHash,
    required DateTime verificationTokenExpiresAt,
  }) async {
    final id = ObjectId();
    final now = DateTime.now().toUtc();
    try {
      await _users.insertOne({
        '_id': id,
        'email': email,
        'passwordHash': passwordHash,
        'displayName': displayName,
        'emailVerified': false,
        'credentialVersion': 0,
        'verificationTokenHash': verificationTokenHash,
        'verificationTokenExpiresAt': verificationTokenExpiresAt,
        'createdAt': now,
        'updatedAt': now,
      });
      // mongo_dart reports server duplicate-key failures as MongoDartError.
      // ignore: avoid_catching_errors
    } on MongoDartError catch (error) {
      if (error.mongoCode == 11000 || error.message.contains('E11000')) {
        throw const AccountAlreadyExists();
      }
      rethrow;
    }
    return id.oid;
  }

  @override
  Future<void> updateVerificationToken(
    String userId,
    String tokenHash,
    DateTime expiresAt,
  ) async {
    final result = await _users.updateOne(
      where.id(_objectId(userId)).eq('emailVerified', false),
      modify
          .set('verificationTokenHash', tokenHash)
          .set('verificationTokenExpiresAt', expiresAt)
          .set('updatedAt', DateTime.now().toUtc()),
    );
    if (result.nMatched != 1) {
      throw StateError(
        'Unverified account was not available for token update.',
      );
    }
  }

  @override
  Future<AuthUser?> consumeVerificationToken(
    String tokenHash,
    DateTime now,
  ) async {
    final document = await _users.findAndModify(
      query: where
          .eq('verificationTokenHash', tokenHash)
          .eq('emailVerified', false)
          .gt('verificationTokenExpiresAt', now),
      update: modify
          .set('emailVerified', true)
          .set('updatedAt', now)
          .unset('verificationTokenHash')
          .unset('verificationTokenExpiresAt'),
      returnNew: true,
    );
    return document == null ? null : _mapUser(document);
  }

  @override
  Future<void> updatePasswordResetToken(
    String email,
    String tokenHash,
    DateTime expiresAt,
  ) async {
    await _users.updateOne(
      where.eq('email', email),
      modify
          .set('passwordResetTokenHash', tokenHash)
          .set('passwordResetExpiresAt', expiresAt)
          .set('updatedAt', DateTime.now().toUtc()),
    );
  }

  @override
  Future<AuthUser?> consumePasswordResetToken(
    String tokenHash,
    String passwordHash,
    DateTime now,
  ) async {
    final document = await _users.findAndModify(
      query: where
          .eq('passwordResetTokenHash', tokenHash)
          .gt('passwordResetExpiresAt', now),
      update: modify
          .set('passwordHash', passwordHash)
          .set('updatedAt', now)
          .inc('credentialVersion', 1)
          .unset('passwordResetTokenHash')
          .unset('passwordResetExpiresAt'),
      returnNew: true,
    );
    return document == null ? null : _mapUser(document);
  }

  @override
  Future<void> createSession({
    required String id,
    required String userId,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) async {
    await _sessions.insertOne({
      '_id': _objectId(id),
      'userId': _objectId(userId),
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'revokedAt': null,
    });
  }

  @override
  Future<bool> hasActiveSession({
    required String id,
    required String userId,
    required DateTime now,
  }) async {
    final session = await _sessions.findOne(
      where
          .id(_objectId(id))
          .eq('userId', _objectId(userId))
          .eq('revokedAt', null)
          .gt('expiresAt', now),
    );
    return session != null;
  }

  @override
  Future<void> revokeSession(
    String id,
    String userId,
    DateTime revokedAt,
  ) async {
    await _sessions.updateOne(
      where
          .id(_objectId(id))
          .eq('userId', _objectId(userId))
          .eq('revokedAt', null),
      modify.set('revokedAt', revokedAt),
    );
  }

  @override
  Future<void> revokeAllSessions(String userId, DateTime revokedAt) async {
    await _sessions.updateMany(
      where.eq('userId', _objectId(userId)).eq('revokedAt', null),
      modify.set('revokedAt', revokedAt),
    );
  }

  static AuthUser _mapUser(Map<String, dynamic> document) {
    final id = document['_id'];
    final email = document['email'];
    final displayName = document['displayName'];
    final emailVerified = document['emailVerified'];
    final credentialVersion = document['credentialVersion'] ?? 0;
    final phone = document['phone'];
    if (id is! ObjectId ||
        email is! String ||
        displayName is! String ||
        emailVerified is! bool ||
        credentialVersion is! num ||
        credentialVersion < 0 ||
        credentialVersion != credentialVersion.toInt() ||
        (phone != null && phone is! String)) {
      throw StateError('User record has invalid authentication fields.');
    }
    return AuthUser(
      id: id.oid,
      email: email,
      displayName: displayName,
      emailVerified: emailVerified,
      credentialVersion: credentialVersion.toInt(),
      phone: phone as String?,
    );
  }

  static ObjectId _objectId(String value) {
    if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value)) {
      throw const FormatException('Invalid user or session ID.');
    }
    return ObjectId.fromHexString(value);
  }
}
