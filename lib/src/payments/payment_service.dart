// ignore_for_file: lines_longer_than_80_chars, curly_braces_in_flow_control_structures, public_member_api_docs

import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/config/app_config.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/orders/order_repository.dart';
import 'package:shop_ease_ecommerce/src/payments/bakong_api_client.dart';
import 'package:shop_ease_ecommerce/src/payments/khqr_generator.dart';
import 'package:shop_ease_ecommerce/src/payments/payment_repository.dart';

/// Coordinates order-owned payments and server-side Bakong verification.
class PaymentService {
  PaymentService(
    this._paymentRepositoryProvider,
    this._orderRepositoryProvider,
    this._config,
    this._bakongClient,
  );

  final PaymentRepositoryProvider _paymentRepositoryProvider;
  final OrderRepositoryProvider _orderRepositoryProvider;
  final AppConfig _config;
  final BakongApiClient _bakongClient;

  Future<Map<String, Object?>> create(
    ObjectId userId,
    ObjectId orderId,
  ) async {
    final paymentRepository = await _paymentRepositoryProvider();
    final existing = await paymentRepository.findByOrder(orderId);
    if (existing != null) return {'payment': _publicPayment(existing)};

    final orderRepository = await _orderRepositoryProvider();
    final order = await orderRepository.findOwnedOrder(userId, orderId);
    if (order == null) _throwOrderNotFound();
    if (order['status'] == 'paid') {
      throw const ApiException(
        statusCode: HttpStatus.conflict,
        code: 'order_already_paid',
        message: 'This order has already been paid.',
      );
    }
    if (order['status'] != 'awaiting_fulfillment') {
      throw const ApiException(
        statusCode: HttpStatus.conflict,
        code: 'order_not_payable',
        message: 'This order is not eligible for payment.',
      );
    }

    final accountId = _config.bakongMerchantAccountId;
    final merchantName = _config.bakongMerchantName;
    final merchantCity = _config.bakongMerchantCity;
    final token = _config.bakongToken;
    if (token == null ||
        token.isEmpty ||
        accountId == null ||
        merchantName == null ||
        merchantCity == null) {
      throw const ApiException(
        statusCode: HttpStatus.serviceUnavailable,
        code: 'bakong_not_configured',
        message: 'Bakong payment integration is not configured.',
      );
    }
    final totalMinor = order['totalMinor'];
    final currency = order['currency'];
    final orderNumber = order['orderNumber'];
    if (totalMinor is! int ||
        totalMinor < 1 ||
        currency is! String ||
        orderNumber is! String) {
      throw StateError('Stored order payment fields are invalid.');
    }

    final now = DateTime.now().toUtc();
    final expiry = now.add(
      Duration(minutes: _config.bakongPaymentExpiryMinutes),
    );
    final paymentId = ObjectId();
    final qr = const KhqrGenerator().generate(
      merchantAccountId: accountId,
      merchantName: merchantName,
      merchantCity: merchantCity,
      paymentReference: orderNumber,
      amountMinor: totalMinor,
      currency: currency,
    );
    try {
      await paymentRepository.insert({
        '_id': paymentId,
        'orderId': orderId,
        'orderNumber': orderNumber,
        'userId': userId,
        'paymentMethod': 'BAKONG_KHQR',
        'amountMinor': totalMinor,
        'currency': currency,
        'status': 'PENDING',
        'khqrPayload': qr['payload'],
        'md5': qr['md5'],
        'paymentReference': orderNumber,
        'expiresAt': expiry,
        'createdAt': now,
        'updatedAt': now,
      });
    } catch (error) {
      if (_isDuplicateKey(error)) {
        final replayed = await paymentRepository.findByOrder(orderId);
        if (replayed != null) {
          return {'payment': _publicPayment(replayed)};
        }
      }
      rethrow;
    }
    final stored = await paymentRepository.findOwned(userId, paymentId);
    if (stored == null)
      throw StateError('Payment insert could not be replayed.');
    return {'payment': _publicPayment(stored)};
  }

  Future<Map<String, Object?>> get(
    ObjectId userId,
    ObjectId paymentId,
  ) async {
    final repository = await _paymentRepositoryProvider();
    var payment = await repository.findOwned(userId, paymentId);
    if (payment == null) _throwPaymentNotFound();
    await _expireIfNeeded(repository, payment);
    payment = await repository.findOwned(userId, paymentId);
    if (payment == null) _throwPaymentNotFound();
    return {'payment': _publicPayment(payment)};
  }

  Future<Map<String, Object?>> verify(
    ObjectId userId,
    ObjectId paymentId,
  ) async {
    final repository = await _paymentRepositoryProvider();
    var payment = await repository.findOwned(userId, paymentId);
    if (payment == null) _throwPaymentNotFound();
    await _expireIfNeeded(repository, payment);
    payment = await repository.findOwned(userId, paymentId);
    if (payment == null) _throwPaymentNotFound();
    if (payment['status'] == 'PAID') {
      await _ensureOrderPaid(repository, payment);
      return {'payment': _publicPayment(payment)};
    }
    if (payment['status'] != 'PENDING') {
      return {'payment': _publicPayment(payment)};
    }

    final md5 = payment['md5'];
    if (md5 is! String) throw StateError('Stored payment MD5 is invalid.');
    final response = await _bakongClient.checkTransactionByMd5(md5);
    final transaction = _extractTransaction(response);
    if (transaction == null) {
      return {'payment': _publicPayment(payment)};
    }
    final success = _isSuccessful(response, transaction);
    if (!success) return {'payment': _publicPayment(payment)};

    final hash = _transactionString(transaction, const [
      'hash',
      'transactionHash',
      'bakongTransactionHash',
    ]);
    if (hash == null) {
      throw const ApiException(
        statusCode: HttpStatus.badGateway,
        code: 'bakong_invalid_response',
        message: 'Bakong returned a transaction without a usable hash.',
      );
    }
    final existingHashPayment = await repository.findByTransactionHash(hash);
    if (existingHashPayment != null &&
        existingHashPayment['_id'] != payment['_id']) {
      throw const ApiException(
        statusCode: HttpStatus.conflict,
        code: 'bakong_transaction_reused',
        message: 'This Bakong transaction has already been used.',
      );
    }

    final amount = _transactionAmount(transaction);
    final expectedAmount = payment['amountMinor'];
    final currency = payment['currency'];
    if (amount == null ||
        expectedAmount is! int ||
        !_amountMatches(amount, expectedAmount, currency)) {
      throw const ApiException(
        statusCode: HttpStatus.conflict,
        code: 'payment_amount_mismatch',
        message: 'The Bakong transaction amount does not match this order.',
      );
    }
    if (!_transactionCurrencyMatches(transaction, currency)) {
      throw const ApiException(
        statusCode: HttpStatus.conflict,
        code: 'payment_currency_mismatch',
        message: 'The Bakong transaction currency does not match this order.',
      );
    }
    final merchantAccount = _config.bakongMerchantAccountId;
    final receiver = _transactionString(transaction, const [
      'toAccountId',
      'receiverAccountId',
      'merchantAccountId',
    ]);
    if (merchantAccount != null &&
        (receiver == null ||
            receiver.toLowerCase() != merchantAccount.toLowerCase())) {
      throw const ApiException(
        statusCode: HttpStatus.conflict,
        code: 'payment_receiver_mismatch',
        message:
            'The Bakong transaction receiver does not match this merchant.',
      );
    }

    final now = DateTime.now().toUtc();
    try {
      await repository.claimPaid(payment['_id'] as ObjectId, hash, now);
    } catch (error) {
      if (_isDuplicateKey(error)) {
        throw const ApiException(
          statusCode: HttpStatus.conflict,
          code: 'bakong_transaction_reused',
          message: 'This Bakong transaction has already been used.',
        );
      }
      rethrow;
    }
    await _ensureOrderPaid(repository, {
      ...payment,
      'status': 'PAID',
      'bakongTransactionHash': hash,
      'paidAt': now,
    });
    final updated = await repository.findOwned(
      userId,
      payment['_id'] as ObjectId,
    );
    if (updated == null)
      throw StateError('Verified payment could not be loaded.');
    return {'payment': _publicPayment(updated)};
  }

  Future<Map<String, Object?>> cancel(
    ObjectId userId,
    ObjectId paymentId,
  ) async {
    final repository = await _paymentRepositoryProvider();
    final payment = await repository.findOwned(userId, paymentId);
    if (payment == null) _throwPaymentNotFound();
    await repository.cancel(paymentId, userId, DateTime.now().toUtc());
    final updated = await repository.findOwned(userId, paymentId);
    if (updated == null)
      throw StateError('Cancelled payment could not be loaded.');
    return {'payment': _publicPayment(updated)};
  }

  Future<void> _expireIfNeeded(
    PaymentRepository repository,
    Map<String, dynamic> payment,
  ) async {
    if (payment['status'] != 'PENDING') return;
    final expiresAt = payment['expiresAt'];
    if (expiresAt is DateTime && expiresAt.isBefore(DateTime.now().toUtc())) {
      await repository.expire(
        payment['_id'] as ObjectId,
        DateTime.now().toUtc(),
      );
    }
  }

  Future<void> _ensureOrderPaid(
    PaymentRepository repository,
    Map<String, dynamic> payment,
  ) async {
    final orderId = payment['orderId'];
    final paidAt = payment['paidAt'];
    if (orderId is ObjectId && paidAt is DateTime) {
      await repository.markOrderPaid(orderId, paidAt);
    }
  }

  static Map<String, dynamic>? _extractTransaction(
    Map<String, dynamic> response,
  ) {
    final data = response['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static bool _isSuccessful(
    Map<String, dynamic> response,
    Map<String, dynamic> transaction,
  ) {
    final responseCode = response['responseCode'];
    final responseSuccess = responseCode == 0 || responseCode == '0';
    final status = _transactionString(transaction, const [
      'status',
      'transactionStatus',
    ])?.toUpperCase();
    final statusSuccessful =
        status == null ||
        const {'SUCCESS', 'SUCCESSFUL', 'PAID', 'COMPLETED'}.contains(status);
    return responseSuccess && statusSuccessful;
  }

  static String? _transactionString(
    Map<String, dynamic> transaction,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = transaction[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  static num? _transactionAmount(Map<String, dynamic> transaction) {
    for (final key in const ['amount', 'amountMinor', 'amountValue']) {
      final value = transaction[key];
      if (value is num) return value;
      if (value is String) return num.tryParse(value);
    }
    return null;
  }

  static bool _amountMatches(
    num bakongAmount,
    int expectedMinor,
    Object? currency,
  ) {
    if (currency == 'USD') return bakongAmount == expectedMinor / 100;
    if (currency == 'KHR') return bakongAmount == expectedMinor;
    return false;
  }

  static bool _transactionCurrencyMatches(
    Map<String, dynamic> transaction,
    Object? currency,
  ) {
    final value = _transactionString(transaction, const [
      'currency',
      'currencyCode',
    ]);
    if (value == null) return false;
    return value.toUpperCase() == currency;
  }

  static Map<String, Object?> _publicPayment(
    Map<String, dynamic> payment,
  ) {
    final id = payment['_id'];
    if (id is! ObjectId) throw StateError('Stored payment ID is invalid.');
    return {
      'id': id.oid,
      'orderId': (payment['orderId'] as ObjectId).oid,
      'amountMinor': payment['amountMinor'],
      'currency': payment['currency'],
      'status': payment['status'],
      'paymentMethod': payment['paymentMethod'],
      'qrPayload': payment['khqrPayload'],
      'md5': payment['md5'],
      'paymentReference': payment['paymentReference'],
      'expiry': payment['expiresAt'],
      'createdAt': payment['createdAt'],
      if (payment['paidAt'] is DateTime) 'paidAt': payment['paidAt'],
    };
  }

  static bool _isDuplicateKey(Object error) {
    if (error is MongoDartError) {
      return error.mongoCode == 11000 || error.message.contains('E11000');
    }
    return false;
  }

  static Never _throwOrderNotFound() {
    throw const ApiException(
      statusCode: HttpStatus.notFound,
      code: 'order_not_found',
      message: 'The order could not be found.',
    );
  }

  static Never _throwPaymentNotFound() {
    throw const ApiException(
      statusCode: HttpStatus.notFound,
      code: 'payment_not_found',
      message: 'The payment could not be found.',
    );
  }
}
