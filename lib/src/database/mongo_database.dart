import 'package:mongo_dart/mongo_dart.dart';

import 'package:shop_ease_ecommerce/src/config/app_config.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_indexes.dart';

/// Reusable MongoDB connection with explicit index and shutdown operations.
class MongoDatabase {
  MongoDatabase._(this._database);

  final Db _database;
  bool _isClosed = false;
  Future<void>? _closeFuture;

  /// Opens a connection to the configured MongoDB database.
  static Future<MongoDatabase> connect(AppConfig config) async {
    final uri = Uri.parse(
      config.mongoUri,
    ).replace(path: '/${config.mongoDatabase}').toString();
    final database = Db(uri);
    await database.open();
    return MongoDatabase._(database);
  }

  /// Whether this handle is open and connected to its MongoDB server.
  bool get isConnected => !_isClosed && _database.isConnected;

  /// Returns a collection handle while this database remains open.
  DbCollection collection(String name) {
    if (_isClosed) {
      throw StateError('The MongoDB connection has been closed.');
    }
    return _database.collection(name);
  }

  /// Creates all application indexes. Existing matching indexes are retained.
  Future<void> ensureIndexes() async {
    if (_isClosed) {
      throw StateError('The MongoDB connection has been closed.');
    }
    await MongoIndexes.ensureCreated(_database);
  }

  /// Closes the connection. Repeated calls are safe.
  Future<void> close() {
    final closing = _closeFuture;
    if (closing != null) return closing;
    _isClosed = true;
    return _closeFuture = _database.close();
  }
}
