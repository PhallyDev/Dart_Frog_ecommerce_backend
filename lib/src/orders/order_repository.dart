import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/database/collection_names.dart';
import 'package:shop_ease_ecommerce/src/database/mongo_database.dart';

/// Lazily supplies order persistence.
typedef OrderRepositoryProvider = Future<OrderRepository> Function();

/// Persistence operations for orders and shipment tracking.
abstract interface class OrderRepository {
  /// Finds one order owned by a user.
  Future<Map<String, dynamic>?> findOwnedOrder(
    ObjectId userId,
    ObjectId orderId,
  );

  /// Finds an order for trusted backend operations.
  Future<Map<String, dynamic>?> findOrder(ObjectId orderId);

  /// Lists a page of one user's orders.
  Future<List<Map<String, dynamic>>> findOrders(
    ObjectId userId, {
    required int skip,
    required int limit,
  });

  /// Counts one user's orders.
  Future<int> countOrders(ObjectId userId);

  /// Marks an eligible order as cancelled.
  Future<Map<String, dynamic>?> cancelOrder(
    ObjectId userId,
    ObjectId orderId,
    DateTime now,
  );

  /// Restores inventory once for a cancelled order and product.
  Future<void> releaseCancellationStock(
    ObjectId orderId,
    ObjectId productId,
    int quantity,
  );

  /// Restores coupon usage once for a cancelled order.
  Future<void> releaseCancellationCouponUse(ObjectId orderId, String code);

  /// Marks all cancellation reservations as released.
  Future<void> completeReservationRelease(ObjectId orderId, DateTime now);

  /// Atomically changes an order status.
  Future<bool> updateOrderStatus(
    ObjectId orderId,
    String expectedStatus,
    String newStatus,
    DateTime now,
  );

  /// Lists tracking events for an order.
  Future<List<Map<String, dynamic>>> findTrackingEvents(ObjectId orderId);

  /// Stores a trusted tracking event.
  Future<void> insertTrackingEvent(Map<String, Object?> event);
}

/// MongoDB-backed order and tracking persistence.
class MongoOrderRepository implements OrderRepository {
  /// Creates the repository using the shared database.
  MongoOrderRepository(this._database);

  final MongoDatabase _database;

  DbCollection get _orders => _database.collection(CollectionNames.orders);
  DbCollection get _tracking =>
      _database.collection(CollectionNames.orderTrackingEvents);
  DbCollection get _products => _database.collection(CollectionNames.products);
  DbCollection get _coupons => _database.collection(CollectionNames.coupons);

  @override
  Future<Map<String, dynamic>?> findOwnedOrder(
    ObjectId userId,
    ObjectId orderId,
  ) => _orders.findOne(where.id(orderId).eq('userId', userId));

  @override
  Future<Map<String, dynamic>?> findOrder(ObjectId orderId) =>
      _orders.findOne(where.id(orderId));

  @override
  Future<List<Map<String, dynamic>>> findOrders(
    ObjectId userId, {
    required int skip,
    required int limit,
  }) => _orders
      .find(
        where
            .eq('userId', userId)
            .sortBy('createdAt', descending: true)
            .skip(skip)
            .limit(limit),
      )
      .toList();

  @override
  Future<int> countOrders(ObjectId userId) =>
      _orders.count(where.eq('userId', userId));

  @override
  Future<Map<String, dynamic>?> cancelOrder(
    ObjectId userId,
    ObjectId orderId,
    DateTime now,
  ) async {
    final order = await findOwnedOrder(userId, orderId);
    if (order == null || order['status'] != 'awaiting_fulfillment') {
      return null;
    }
    final result = await _orders.updateOne(
      {
        '_id': orderId,
        'userId': userId,
        'status': 'awaiting_fulfillment',
      },
      modify
          .set('status', 'cancelled')
          .set('reservationReleaseState', 'pending')
          .set('updatedAt', now),
    );
    return result.nMatched == 1
        ? {
            ...order,
            'status': 'cancelled',
            'reservationReleaseState': 'pending',
          }
        : null;
  }

  @override
  Future<void> releaseCancellationStock(
    ObjectId orderId,
    ObjectId productId,
    int quantity,
  ) async {
    await _products.updateOne(
      {
        '_id': productId,
        'cancellationReleaseOrderIds': {r'$ne': orderId},
      },
      {
        r'$inc': {'stock': quantity},
        r'$addToSet': {'cancellationReleaseOrderIds': orderId},
        r'$set': {'updatedAt': DateTime.now().toUtc()},
      },
    );
  }

  @override
  Future<void> releaseCancellationCouponUse(
    ObjectId orderId,
    String code,
  ) async {
    await _coupons.updateOne(
      {
        'code': code,
        'usageCount': {r'$gt': 0},
        'cancellationReleaseOrderIds': {r'$ne': orderId},
      },
      {
        r'$inc': {'usageCount': -1},
        r'$addToSet': {'cancellationReleaseOrderIds': orderId},
        r'$set': {'updatedAt': DateTime.now().toUtc()},
      },
    );
  }

  @override
  Future<void> completeReservationRelease(
    ObjectId orderId,
    DateTime now,
  ) async {
    await _orders.updateOne(
      where
          .id(orderId)
          .eq('status', 'cancelled')
          .eq('reservationReleaseState', 'pending'),
      modify
          .set('reservationReleaseState', 'complete')
          .set('reservationsReleased', true)
          .set('updatedAt', now),
    );
  }

  @override
  Future<bool> updateOrderStatus(
    ObjectId orderId,
    String expectedStatus,
    String newStatus,
    DateTime now,
  ) async {
    final result = await _orders.updateOne(
      where.id(orderId).eq('status', expectedStatus),
      modify.set('status', newStatus).set('updatedAt', now),
    );
    return result.nMatched == 1;
  }

  @override
  Future<List<Map<String, dynamic>>> findTrackingEvents(ObjectId orderId) =>
      _tracking
          .find(
            where.eq('orderId', orderId).sortBy('occurredAt').sortBy('_id'),
          )
          .toList();

  @override
  Future<void> insertTrackingEvent(Map<String, Object?> event) async {
    await _tracking.insertOne(event);
  }
}
