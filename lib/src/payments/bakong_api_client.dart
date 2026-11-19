import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:shop_ease_ecommerce/src/config/app_config.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

/// Dedicated, timeout-bounded Bakong transaction-verification client.
class BakongApiClient {
  BakongApiClient(this._config, {HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final AppConfig _config;
  final HttpClient _httpClient;

  Future<Map<String, dynamic>> checkTransactionByMd5(String md5) async {
    final token = _config.bakongToken;
    if (token == null || token.isEmpty) {
      throw const ApiException(
        statusCode: HttpStatus.serviceUnavailable,
        code: 'bakong_not_configured',
        message: 'Bakong payment integration is not configured.',
      );
    }

    HttpClientRequest? request;
    try {
      final uri = Uri.parse(
        _config.bakongBaseUrl,
      ).resolve('/v1/check_transaction_by_md5');
      request = await _httpClient
          .postUrl(uri)
          .timeout(
            Duration(seconds: _config.bakongRequestTimeoutSeconds),
          );
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..set('X-API-Key', token)
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.acceptHeader, 'application/json');
      request.write(jsonEncode({'md5': md5}));
      final response = await request.close().timeout(
        Duration(seconds: _config.bakongRequestTimeoutSeconds),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden) {
        throw const ApiException(
          statusCode: HttpStatus.serviceUnavailable,
          code: 'bakong_authentication_failed',
          message: 'Bakong rejected the configured API credentials.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          statusCode: HttpStatus.badGateway,
          code: 'bakong_api_error',
          message: 'Bakong payment verification is temporarily unavailable.',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const ApiException(
          statusCode: HttpStatus.badGateway,
          code: 'bakong_invalid_response',
          message: 'Bakong returned an invalid verification response.',
        );
      }
      return Map<String, dynamic>.from(decoded);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        statusCode: HttpStatus.gatewayTimeout,
        code: 'bakong_timeout',
        message: 'Bakong payment verification timed out.',
      );
    } on SocketException {
      throw const ApiException(
        statusCode: HttpStatus.badGateway,
        code: 'bakong_network_error',
        message: 'Bakong payment verification is unavailable.',
      );
    } on FormatException {
      throw const ApiException(
        statusCode: HttpStatus.badGateway,
        code: 'bakong_invalid_response',
        message: 'Bakong returned an invalid verification response.',
      );
    } finally {
      request?.abort();
    }
  }
}
