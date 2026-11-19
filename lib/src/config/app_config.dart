import 'dart:io';

import 'package:dotenv/dotenv.dart';

/// Supported runtime environments.
enum AppEnvironment {
  /// Local development environment.
  development,

  /// Automated test environment.
  test,

  /// Production environment.
  production;

  /// Parses a configured environment name.
  static AppEnvironment parse(String value) {
    return switch (value) {
      'development' => AppEnvironment.development,
      'test' => AppEnvironment.test,
      'production' => AppEnvironment.production,
      _ => throw const FormatException(
        'APP_ENV must be development, test, or production.',
      ),
    };
  }
}

/// Validated configuration loaded from a `.env` file and process variables.
class AppConfig {
  /// Creates application configuration with validated values.
  const AppConfig({
    required this.mongoUri,
    required this.mongoDatabase,
    required this.environment,
    this.jwtSecret,
    this.jwtAccessTokenTtlMinutes = defaultJwtAccessTokenTtlMinutes,
    this.smtpHost,
    this.smtpPort = 587,
    this.smtpUsername,
    this.smtpPassword,
    this.smtpSender,
    this.publicApiBaseUrl = 'http://localhost:8080',
    this.orderOperationsToken,
    this.bakongToken,
    this.bakongBaseUrl = 'https://api-bakong.nbc.gov.kh',
    this.bakongMerchantAccountId,
    this.bakongMerchantName,
    this.bakongMerchantCity,
    this.bakongRequestTimeoutSeconds = 15,
    this.bakongPaymentExpiryMinutes = 30,
  });

  /// Reads `.env`, then applies process variables as overrides.
  factory AppConfig.load({
    String envPath = '.env',
    Map<String, String>? environment,
  }) {
    final dotenv = DotEnv(quiet: true)
      ..load([envPath])
      ..addAll(environment ?? Platform.environment);
    final values = <String, String>{};
    for (final name in _supportedEnvironmentKeys) {
      final value = dotenv[name];
      if (value != null) values[name] = value;
    }
    return AppConfig.fromMap(values);
  }

  /// Creates validated configuration from environment-style key/value pairs.
  factory AppConfig.fromMap(Map<String, String> values) {
    final mongoUri = _required(values, 'MONGODB_URI');
    final mongoDatabase = _required(values, 'MONGODB_DATABASE');
    final jwtSecret = _optional(values, 'JWT_SECRET');
    final jwtAccessTokenTtlMinutesValue = _optional(
      values,
      'JWT_ACCESS_TOKEN_TTL_MINUTES',
    );
    final jwtAccessTokenTtlMinutes = jwtAccessTokenTtlMinutesValue == null
        ? defaultJwtAccessTokenTtlMinutes
        : int.tryParse(jwtAccessTokenTtlMinutesValue);
    final smtpHost = _optional(values, 'SMTP_HOST');
    final smtpUsername = _optional(values, 'SMTP_USERNAME');
    final smtpPassword = _optional(values, 'SMTP_PASSWORD');
    final smtpSender = _optional(values, 'SMTP_SENDER');
    final smtpPortValue = _optional(values, 'SMTP_PORT');
    final orderOperationsToken = _optional(values, 'ORDER_OPERATIONS_TOKEN');
    final bakongToken = _optional(values, 'BAKONG_TOKEN');
    final bakongMerchantAccountId = _optional(
      values,
      'BAKONG_MERCHANT_ACCOUNT_ID',
    );
    final bakongMerchantName = _optional(values, 'BAKONG_MERCHANT_NAME');
    final bakongMerchantCity = _optional(values, 'BAKONG_MERCHANT_CITY');
    final bakongBaseUrl =
        _optional(values, 'BAKONG_BASE_URL') ?? 'https://api-bakong.nbc.gov.kh';
    final bakongRequestTimeoutSecondsValue = _optional(
      values,
      'BAKONG_REQUEST_TIMEOUT_SECONDS',
    );
    final bakongPaymentExpiryMinutesValue = _optional(
      values,
      'BAKONG_PAYMENT_EXPIRY_MINUTES',
    );

    final uri = Uri.tryParse(mongoUri);
    if (uri == null ||
        !const {'mongodb', 'mongodb+srv'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException(
        'MONGODB_URI must be a valid mongodb:// or mongodb+srv:// URI.',
      );
    }

    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(mongoDatabase)) {
      throw const FormatException(
        'MONGODB_DATABASE contains unsupported characters.',
      );
    }

    final environment = values['APP_ENV']?.trim();
    final appEnvironment = AppEnvironment.parse(
      environment == null || environment.isEmpty ? 'development' : environment,
    );
    if (orderOperationsToken != null && orderOperationsToken.length < 32) {
      throw const FormatException(
        'ORDER_OPERATIONS_TOKEN must be at least 32 characters.',
      );
    }
    if (jwtSecret != null && jwtSecret.length < 32) {
      throw const FormatException('JWT_SECRET must be at least 32 characters.');
    }
    if (jwtAccessTokenTtlMinutes == null ||
        jwtAccessTokenTtlMinutes < 1 ||
        jwtAccessTokenTtlMinutes > 60) {
      throw const FormatException(
        'JWT_ACCESS_TOKEN_TTL_MINUTES must be between 1 and 60.',
      );
    }

    final smtpConfigured = [
      smtpHost,
      smtpUsername,
      smtpPassword,
      smtpSender,
    ].any((value) => value != null);
    if (smtpConfigured &&
        [smtpHost, smtpUsername, smtpPassword, smtpSender].any(
          (value) => value == null,
        )) {
      throw const FormatException(
        'SMTP_HOST, SMTP_USERNAME, SMTP_PASSWORD, and SMTP_SENDER must all be '
        'configured together.',
      );
    }
    final smtpPort = smtpPortValue == null ? 587 : int.tryParse(smtpPortValue);
    if (smtpPort == null || smtpPort < 1 || smtpPort > 65535) {
      throw const FormatException('SMTP_PORT must be between 1 and 65535.');
    }

    final publicApiBaseUrl =
        _optional(values, 'PUBLIC_API_BASE_URL') ?? 'http://localhost:8080';
    final publicUri = Uri.tryParse(publicApiBaseUrl);
    if (publicUri == null ||
        !const {'http', 'https'}.contains(publicUri.scheme) ||
        publicUri.host.isEmpty ||
        (appEnvironment == AppEnvironment.production &&
            publicUri.scheme != 'https')) {
      throw const FormatException(
        'PUBLIC_API_BASE_URL must be an absolute URL (HTTPS in production).',
      );
    }
    final bakongUri = Uri.tryParse(bakongBaseUrl);
    if (bakongUri == null ||
        !const {'http', 'https'}.contains(bakongUri.scheme) ||
        bakongUri.host.isEmpty ||
        (appEnvironment == AppEnvironment.production &&
            bakongUri.scheme != 'https')) {
      throw const FormatException(
        'BAKONG_BASE_URL must be an absolute HTTP(S) URL.',
      );
    }
    final timeout = bakongRequestTimeoutSecondsValue == null
        ? 15
        : int.tryParse(bakongRequestTimeoutSecondsValue);
    if (timeout == null || timeout < 2 || timeout > 120) {
      throw const FormatException(
        'BAKONG_REQUEST_TIMEOUT_SECONDS must be between 2 and 120.',
      );
    }
    final expiry = bakongPaymentExpiryMinutesValue == null
        ? 30
        : int.tryParse(bakongPaymentExpiryMinutesValue);
    if (expiry == null || expiry < 1 || expiry > 1440) {
      throw const FormatException(
        'BAKONG_PAYMENT_EXPIRY_MINUTES must be between 1 and 1440.',
      );
    }

    return AppConfig(
      mongoUri: mongoUri,
      mongoDatabase: mongoDatabase,
      environment: appEnvironment,
      jwtSecret: jwtSecret,
      jwtAccessTokenTtlMinutes: jwtAccessTokenTtlMinutes,
      smtpHost: smtpHost,
      smtpPort: smtpPort,
      smtpUsername: smtpUsername,
      smtpPassword: smtpPassword,
      smtpSender: smtpSender,
      publicApiBaseUrl: publicApiBaseUrl,
      orderOperationsToken: orderOperationsToken,
      bakongToken: bakongToken,
      bakongBaseUrl: bakongBaseUrl,
      bakongMerchantAccountId: bakongMerchantAccountId,
      bakongMerchantName: bakongMerchantName,
      bakongMerchantCity: bakongMerchantCity,
      bakongRequestTimeoutSeconds: timeout,
      bakongPaymentExpiryMinutes: expiry,
    );
  }

  /// MongoDB connection URI. Treat as secret when it contains credentials.
  final String mongoUri;

  /// Database name used by the application.
  final String mongoDatabase;

  /// Runtime environment used for environment-specific behavior.
  final AppEnvironment environment;

  /// HMAC signing secret; required by the authentication module.
  final String? jwtSecret;

  /// Access-token lifetime in minutes, defaulting to 15 and capped at 60.
  final int jwtAccessTokenTtlMinutes;

  /// Optional SMTP host for verification and password-recovery mail.
  final String? smtpHost;

  /// SMTP port, defaulting to STARTTLS port 587.
  final int smtpPort;

  /// Optional SMTP username.
  final String? smtpUsername;

  /// Optional SMTP password.
  final String? smtpPassword;

  /// Verified sender email address.
  final String? smtpSender;

  /// Public API origin included in authentication email instructions.
  final String publicApiBaseUrl;

  /// Optional bearer token for trusted order-operations endpoints.
  final String? orderOperationsToken;
  final String? bakongToken;
  final String bakongBaseUrl;
  final String? bakongMerchantAccountId;
  final String? bakongMerchantName;
  final String? bakongMerchantCity;
  final int bakongRequestTimeoutSeconds;
  final int bakongPaymentExpiryMinutes;

  static String _required(Map<String, String> values, String name) {
    final value = values[name]?.trim();
    if (value == null || value.isEmpty) {
      throw FormatException('$name is required.');
    }
    return value;
  }

  static String? _optional(Map<String, String> values, String name) {
    final value = values[name]?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static const _supportedEnvironmentKeys = [
    'APP_ENV',
    'MONGODB_URI',
    'MONGODB_DATABASE',
    'JWT_SECRET',
    'JWT_ACCESS_TOKEN_TTL_MINUTES',
    'SMTP_HOST',
    'SMTP_PORT',
    'SMTP_USERNAME',
    'SMTP_PASSWORD',
    'SMTP_SENDER',
    'PUBLIC_API_BASE_URL',
    'ORDER_OPERATIONS_TOKEN',
    'BAKONG_TOKEN',
    'BAKONG_BASE_URL',
    'BAKONG_MERCHANT_ACCOUNT_ID',
    'BAKONG_MERCHANT_NAME',
    'BAKONG_MERCHANT_CITY',
    'BAKONG_REQUEST_TIMEOUT_SECONDS',
    'BAKONG_PAYMENT_EXPIRY_MINUTES',
  ];

  /// Default short-lived access-token lifetime.
  static const defaultJwtAccessTokenTtlMinutes = 15;
}
