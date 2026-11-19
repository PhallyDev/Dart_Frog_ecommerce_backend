// ignore_for_file: public_member_api_docs

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/database/collection_names.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database.dart';

typedef PaymentRepositoryProvider = Future<PaymentRepository> Function();

abstract interface class PaymentRepository {
  Future<Map<String, dynamic>?> findByOrder(ObjectId orderId);
  Future<Map<String, dynamic>?> findOwned(ObjectId userId, ObjectId paymentId);
  Future<Map<String, dynamic>?> findByTransactionHash(String hash);
  Future<void> insert(Map<String, Object?> payment);
  Future<bool> claimPaid(
    ObjectId paymentId,
    String transactionHash,
    DateTime paidAt,
  );
  Future<bool> cancel(ObjectId paymentId, ObjectId userId, DateTime now);
  Future<bool> expire(ObjectId paymentId, DateTime now);
  Future<bool> markOrderPaid(ObjectId orderId, DateTime paidAt);
}

class MongoPaymentRepository implements PaymentRepository {
  MongoPaymentRepository(this._database);

  final MongoDatabase _database;

  DbCollection get _payments => _database.collection(CollectionNames.payments);
  DbCollection get _orders => _database.collection(CollectionNames.orders);

  @override
  Future<Map<String, dynamic>?> findByOrder(ObjectId orderId) =>
      _payments.findOne(where.eq('orderId', orderId));

  @override
  Future<Map<String, dynamic>?> findOwned(
    ObjectId userId,
    ObjectId paymentId,
  ) => _payments.findOne(where.id(paymentId).eq('userId', userId));

  @override
  Future<Map<String, dynamic>?> findByTransactionHash(String hash) =>
      _payments.findOne(where.eq('bakongTransactionHash', hash));

  @override
  Future<void> insert(Map<String, Object?> payment) async {
    await _payments.insertOne(payment);
  }

  @override
  Future<bool> claimPaid(
    ObjectId paymentId,
    String transactionHash,
    DateTime paidAt,
  ) async {
    final result = await _payments.updateOne(
      {
        '_id': paymentId,
        r'$or': [
          {'status': 'PENDING'},
          {'status': 'PAID'},
        ],
      },
      modify
          .set('status', 'PAID')
          .set('bakongTransactionHash', transactionHash)
          .set('paidAt', paidAt)
          .set('updatedAt', paidAt),
      upsert: false,
    );
    return result.nMatched == 1;
  }

  @override
  Future<bool> cancel(
    ObjectId paymentId,
    ObjectId userId,
    DateTime now,
  ) async {
    final result = await _payments.updateOne(
      {
        '_id': paymentId,
        'userId': userId,
        'status': 'PENDING',
      },
      modify.set('status', 'CANCELLED').set('updatedAt', now),
    );
    return result.nMatched == 1;
  }

  @override
  Future<bool> expire(ObjectId paymentId, DateTime now) async {
    final result = await _payments.updateOne(
      {
        '_id': paymentId,
        'status': 'PENDING',
        'expiresAt': {r'$lte': now},
      },
      modify.set('status', 'EXPIRED').set('updatedAt', now),
    );
    return result.nMatched == 1;
  }

  @override
  Future<bool> markOrderPaid(ObjectId orderId, DateTime paidAt) async {
    final result = await _orders.updateOne(
      {
        '_id': orderId,
        r'$or': [
          {'status': 'awaiting_fulfillment'},
          {'status': 'paid'},
        ],
      },
      modify
          .set('status', 'paid')
          .set('paidAt', paidAt)
          .set('updatedAt', paidAt),
    );
    return result.nMatched == 1;
  }
}
