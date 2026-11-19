import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/database/collection_names.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database.dart';

/// Lazily supplies account persistence.
typedef AccountRepositoryProvider = Future<AccountRepository> Function();

/// Persistence operations for user profiles and settings.
abstract interface class AccountRepository {
  /// Finds one user's account document.
  Future<Map<String, dynamic>?> findUser(ObjectId userId);

  /// Updates validated profile fields and returns the updated user.
  Future<Map<String, dynamic>?> updateProfile(
    ObjectId userId,
    Map<String, Object?> updates,
    DateTime now,
  );

  /// Finds one user's stored settings.
  Future<Map<String, dynamic>?> findSettings(ObjectId userId);

  /// Persists a user's selected theme preference.
  Future<void> saveTheme(ObjectId userId, String theme, DateTime now);
}

/// MongoDB-backed persistence for profiles and user settings.
class MongoAccountRepository implements AccountRepository {
  /// Creates the repository using the shared MongoDB connection.
  const MongoAccountRepository(this._database);

  final MongoDatabase _database;

  DbCollection get _users => _database.collection(CollectionNames.users);
  DbCollection get _settings =>
      _database.collection(CollectionNames.userSettings);

  @override
  Future<Map<String, dynamic>?> findUser(ObjectId userId) =>
      _users.findOne(where.id(userId));

  @override
  Future<Map<String, dynamic>?> updateProfile(
    ObjectId userId,
    Map<String, Object?> updates,
    DateTime now,
  ) async {
    final setFields = <String, Object>{'updatedAt': now};
    final unsetFields = <String, Object>{};
    if (updates.containsKey('displayName')) {
      setFields['displayName'] = updates['displayName']! as String;
    }
    if (updates.containsKey('phone')) {
      final phone = updates['phone'];
      if (phone == null) {
        unsetFields['phone'] = '';
      } else {
        setFields['phone'] = phone as String;
      }
    }

    final update = <String, Object>{
      r'$set': setFields,
      if (unsetFields.isNotEmpty) r'$unset': unsetFields,
    };
    final result = await _users.updateOne(where.id(userId), update);
    if (result.nMatched != 1) return null;
    return _users.findOne(where.id(userId));
  }

  @override
  Future<Map<String, dynamic>?> findSettings(ObjectId userId) =>
      _settings.findOne(where.eq('userId', userId));

  @override
  Future<void> saveTheme(ObjectId userId, String theme, DateTime now) async {
    try {
      await _settings.updateOne(
        {'userId': userId},
        {
          r'$set': {'theme': theme, 'updatedAt': now},
          r'$setOnInsert': {'userId': userId, 'createdAt': now},
        },
        upsert: true,
      );
      // A concurrent first write may win the unique userId index.
      // ignore: avoid_catching_errors
    } on MongoDartError catch (error) {
      if (error.mongoCode != 11000 && !error.message.contains('E11000')) {
        rethrow;
      }
      final result = await _settings.updateOne(
        {'userId': userId},
        {
          r'$set': {'theme': theme, 'updatedAt': now},
        },
      );
      if (result.nMatched != 1) {
        throw StateError('Concurrent user settings update could not be saved.');
      }
    }
  }
}
