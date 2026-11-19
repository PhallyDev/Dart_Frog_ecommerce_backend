import 'dart:io';

import 'package:shop_ease_ecommerce/src/config/app_config.dart';
import 'package:test/test.dart';

void main() {
  group('AppConfig.fromMap', () {
    const requiredValues = {
      'MONGODB_URI': 'mongodb://127.0.0.1:27017/shop_ease_ecommerce',
      'MONGODB_DATABASE': 'shop_ease_ecommerce',
    };

    test('parses valid MongoDB settings and defaults to development.', () {
      final config = AppConfig.fromMap(requiredValues);

      expect(config.mongoUri, requiredValues['MONGODB_URI']);
      expect(config.mongoDatabase, 'shop_ease_ecommerce');
      expect(config.environment, AppEnvironment.development);
      expect(config.jwtAccessTokenTtlMinutes, 15);
    });

    test(
      'accepts a configured access-token lifetime within the safe range.',
      () {
        final config = AppConfig.fromMap({
          ...requiredValues,
          'JWT_ACCESS_TOKEN_TTL_MINUTES': '30',
        });

        expect(config.jwtAccessTokenTtlMinutes, 30);
      },
    );

    test('rejects invalid access-token lifetime values.', () {
      for (final value in ['0', '61', 'not-a-number']) {
        expect(
          () => AppConfig.fromMap({
            ...requiredValues,
            'JWT_ACCESS_TOKEN_TTL_MINUTES': value,
          }),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('rejects a missing MongoDB URI.', () {
      expect(
        () => AppConfig.fromMap({'MONGODB_DATABASE': 'shop_ease_ecommerce'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-MongoDB URI schemes.', () {
      expect(
        () => AppConfig.fromMap({
          ...requiredValues,
          'MONGODB_URI': 'https://example.invalid/database',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unsupported application environments.', () {
      expect(
        () => AppConfig.fromMap({...requiredValues, 'APP_ENV': 'staging'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a weak JWT secret.', () {
      expect(
        () => AppConfig.fromMap({
          ...requiredValues,
          'JWT_SECRET': 'replace-me',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('requires complete SMTP configuration when email is enabled.', () {
      expect(
        () => AppConfig.fromMap({
          ...requiredValues,
          'SMTP_HOST': 'smtp.example.test',
          'SMTP_USERNAME': 'user',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('requires HTTPS public origin in production.', () {
      expect(
        () => AppConfig.fromMap({
          ...requiredValues,
          'APP_ENV': 'production',
          'PUBLIC_API_BASE_URL': 'http://api.example.test',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('process values override values loaded from the env file.', () async {
    final directory = await Directory.systemTemp.createTemp('shopease-env-');
    addTearDown(() => directory.delete(recursive: true));
    final envFile = File('${directory.path}${Platform.pathSeparator}.env');
    await envFile.writeAsString(
      'MONGODB_URI=mongodb://env-file:27017/shop_ease_ecommerce\n'
      'MONGODB_DATABASE=shop_ease_ecommerce\n',
    );

    final config = AppConfig.load(
      envPath: envFile.path,
      environment: const {
        'MONGODB_URI': 'mongodb+srv://server-value.example/shop_ease_ecommerce',
      },
    );

    expect(config.mongoUri, startsWith('mongodb+srv://server-value.example'));
  });
}
