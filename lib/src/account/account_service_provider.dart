import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/src/account/account_repository.dart';
import 'package:shop_ease_ecommerce/src/account/account_service.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database_provider.dart';

/// Provides profile and settings operations backed by the shared database.
Handler provideAccountService(Handler handler) {
  return (context) {
    final service = AccountService(
      () async => MongoAccountRepository(await MongoDatabaseProvider.instance),
    );
    return handler(context.provide<AccountService>(() => service));
  };
}
