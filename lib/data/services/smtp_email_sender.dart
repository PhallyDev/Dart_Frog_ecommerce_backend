import 'dart:async';
import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shop_ease_ecommerce/application/ports/email_sender.dart';
import 'package:shop_ease_ecommerce/src/config/app_config.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

/// SMTP-backed email sender. Authentication tokens are only sent to recipients.
class SmtpEmailSender implements EmailSender {
  /// Creates an SMTP sender from validated environment configuration.
  const SmtpEmailSender(this._config);

  final AppConfig _config;

  @override
  Future<void> sendVerification(String email, String token) {
    final endpoint = Uri.parse(
      _config.publicApiBaseUrl,
    ).resolve('/api/v1/auth/verify-email');
    return _send(
      email,
      'Verify your ShopEase email',
      'Submit this token to $endpoint using POST with JSON body '
          '{"token":"$token"}. The token expires in 30 minutes.',
    );
  }

  @override
  Future<void> sendPasswordReset(String email, String token) {
    final endpoint = Uri.parse(
      _config.publicApiBaseUrl,
    ).resolve('/api/v1/auth/reset-password');
    return _send(
      email,
      'Reset your ShopEase password',
      'Submit this token to $endpoint using POST with JSON body '
          '{"token":"$token","password":"your-new-password"}. '
          'The token expires in 20 minutes.',
    );
  }

  Future<void> _send(String recipient, String subject, String text) async {
    final host = _config.smtpHost;
    final username = _config.smtpUsername;
    final password = _config.smtpPassword;
    final sender = _config.smtpSender;
    if (host == null ||
        username == null ||
        password == null ||
        sender == null) {
      throw const ApiException(
        statusCode: 503,
        code: 'email_delivery_unavailable',
        message: 'Email delivery is not configured.',
      );
    }

    final message = Message()
      ..from = Address(sender, 'ShopEase')
      ..recipients.add(recipient)
      ..subject = subject
      ..text = text;
    try {
      await send(
        message,
        SmtpServer(
          host,
          port: _config.smtpPort,
          username: username,
          password: password,
          ssl: _config.smtpPort == 465,
        ),
        timeout: const Duration(seconds: 15),
      );
    } on MailerException {
      _throwDeliveryFailure();
    } on IOException {
      _throwDeliveryFailure();
    } on TimeoutException {
      _throwDeliveryFailure();
    }
  }

  Never _throwDeliveryFailure() {
    throw const ApiException(
      statusCode: 503,
      code: 'email_delivery_failed',
      message: 'Email delivery is temporarily unavailable.',
    );
  }
}
