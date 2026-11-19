import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/config/app_config.dart';
import 'package:shop_ease_ecommerce/src/database/collection_names.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database.dart';
import 'package:shop_ease_ecommerce/src/database/seed_data.dart';

Future<void> main() async {
  final config = AppConfig.load();
  if (config.environment != AppEnvironment.development) {
    throw StateError('The demo seed command is restricted to development.');
  }

  final database = await MongoDatabase.connect(config);
  try {
    await database.ensureIndexes();
    final now = DateTime.now().toUtc();
    await _insertMissing(
      database,
      CollectionNames.categories,
      'slug',
      SeedData.categories,
      now,
    );
    final storedCategories = await database
        .collection(CollectionNames.categories)
        .find()
        .toList();
    final categoryIds = <String, ObjectId>{};
    for (final category in storedCategories) {
      final slug = category['slug'];
      final id = category['_id'];
      if (slug is String && id is ObjectId) categoryIds[slug] = id;
    }
    await _insertMissing(
      database,
      CollectionNames.products,
      'slug',
      SeedData.productsFor(categoryIds),
      now,
    );
    await _insertMissing(
      database,
      CollectionNames.coupons,
      'code',
      SeedData.coupons,
      now,
    );
    await _insertMissing(
      database,
      CollectionNames.shippingMethods,
      'code',
      SeedData.shippingMethods,
      now,
    );
    stdout.writeln(
      'Development fixtures are ready. Existing documents and inventory were '
      'preserved.',
    );
  } finally {
    await database.close();
  }
}

Future<void> _insertMissing(
  MongoDatabase database,
  String collection,
  String uniqueField,
  List<Map<String, Object?>> documents,
  DateTime now,
) async {
  final target = database.collection(collection);
  for (final document in documents) {
    final key = document[uniqueField];
    if (key == null) {
      throw StateError('A seed document is missing $uniqueField.');
    }
    await target.updateOne(
      {uniqueField: key},
      {
        r'$setOnInsert': {
          ...document,
          'createdAt': now,
          'updatedAt': now,
        },
      },
      upsert: true,
    );
  }
}
