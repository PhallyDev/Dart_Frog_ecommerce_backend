import 'package:shop_ease_ecommerce/src/config/app_config.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database.dart';

/// Lazily opens and shares one MongoDB connection for the server process.
abstract final class MongoDatabaseProvider {
  static MongoDatabase? _database;
  static Future<MongoDatabase>? _opening;

  /// Returns the shared connection, opening it and ensuring indexes if needed.
  static Future<MongoDatabase> get instance {
    final database = _database;
    if (database != null) return Future.value(database);
    return _opening ??= _connect().then(
      (database) {
        _database = database;
        _opening = null;
        return database;
      },
      onError: (Object error, StackTrace stackTrace) {
        _opening = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  static Future<MongoDatabase> _connect() async {
    final database = await MongoDatabase.connect(AppConfig.load());
    try {
      await database.ensureIndexes();
      return database;
    } catch (_) {
      await database.close();
      rethrow;
    }
  }
}
