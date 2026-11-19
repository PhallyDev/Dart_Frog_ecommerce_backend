import 'package:dart_frog/dart_frog.dart';
import 'package:shop_ease_ecommerce/application/use_cases/auth/auth_service.dart';
import 'package:shop_ease_ecommerce/core/security/access_token_service.dart';
import 'package:shop_ease_ecommerce/data/repositories/mongo_auth_repository.dart';
import 'package:shop_ease_ecommerce/data/services/smtp_email_sender.dart';
import 'package:shop_ease_ecommerce/src/config/app_config.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database_provider.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

/// Provides the configured authentication service to protected route trees.
Handler provideAuthService(Handler handler) {
  return (context) {
    final AppConfig config;
    try {
      config = AppConfig.load();
    } on FormatException {
      throw const ApiException(
        statusCode: 503,
        code: 'authentication_not_configured',
        message: 'Authentication is not configured on this server.',
      );
    }
    final jwtSecret = config.jwtSecret;
    if (jwtSecret == null) {
      throw const ApiException(
        statusCode: 503,
        code: 'authentication_not_configured',
        message: 'Authentication is not configured on this server.',
      );
    }
    final service = AuthService(
      repositoryProvider: () async => MongoAuthRepository(
        await MongoDatabaseProvider.instance,
      ),
      jwtSecret: jwtSecret,
      emailSender: SmtpEmailSender(config),
      accessTokenService: AccessTokenService(
        jwtSecret,
        lifetime: Duration(minutes: config.jwtAccessTokenTtlMinutes),
      ),
    );
    return handler(context.provide<AuthService>(() => service));
  };
}
