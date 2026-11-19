import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/models/pagination.dart';
import 'package:shop_ease_ecommerce/src/orders/order_repository.dart';

/// User-owned order history, cancellation, and tracking operations.
class OrderService {
  /// Creates the service using a repository provider.
  OrderService(this._repositoryProvider);

  final OrderRepositoryProvider _repositoryProvider;

  /// Returns a page of the user's orders.
  Future<Map<String, Object?>> list(
    ObjectId userId,
    Map<String, String> parameters,
  ) async {
    final pagination = Pagination.parse(parameters);
    final repository = await _repositoryProvider();
    final orders = await repository.findOrders(
      userId,
      skip: pagination.offset,
      limit: pagination.limit,
    );
    final total = await repository.countOrders(userId);
    return {
      'data': orders.map(_publicOrder).toList(),
      'pagination': pagination.metadata(total),
    };
  }

  /// Retrieves one order only when it belongs to the requesting user.
  Future<Map<String, Object?>> get(
    ObjectId userId,
    ObjectId orderId,
  ) async {
    final repository = await _repositoryProvider();
    final order = await repository.findOwnedOrder(userId, orderId);
    if (order == null) _throwOrderNotFound();
    return {'order': _publicOrder(order)};
  }

  /// Cancels an eligible order and releases its inventory/coupon reservations.
  Future<Map<String, Object?>> cancel(
    ObjectId userId,
    ObjectId orderId,
  ) async {
    final repository = await _repositoryProvider();
    final existing = await repository.findOwnedOrder(userId, orderId);
    if (existing == null) _throwOrderNotFound();
    final Map<String, dynamic> cancelled;
    if (existing['status'] == 'cancelled') {
      if (existing['reservationReleaseState'] == 'complete') {
        return {'order': _publicOrder(existing)};
      }
      if (existing['reservationReleaseState'] != 'pending') {
        throw StateError('Cancelled order reservation state is invalid.');
      }
      cancelled = existing;
    } else {
      if (existing['status'] != 'awaiting_fulfillment') {
        throw const ApiException(
          statusCode: HttpStatus.conflict,
          code: 'order_not_cancellable',
          message:
              'This order cannot be cancelled while fulfillment is in '
              'progress.',
        );
      }
      final result = await repository.cancelOrder(
        userId,
        orderId,
        DateTime.now().toUtc(),
      );
      if (result == null) {
        throw const ApiException(
          statusCode: HttpStatus.conflict,
          code: 'order_not_cancellable',
          message: 'This order can no longer be cancelled.',
        );
      }
      cancelled = result;
    }

    final rawItems = cancelled['items'];
    if (rawItems is! List) {
      throw StateError('Stored order items are invalid.');
    }
    final quantitiesByProduct = <ObjectId, int>{};
    for (final rawItem in rawItems) {
      if (rawItem is! Map ||
          rawItem['productId'] is! ObjectId ||
          rawItem['quantity'] is! int ||
          (rawItem['quantity'] as int) < 1) {
        throw StateError('Stored order item reservation is invalid.');
      }
      final productId = rawItem['productId'] as ObjectId;
      quantitiesByProduct.update(
        productId,
        (quantity) => quantity + (rawItem['quantity'] as int),
        ifAbsent: () => rawItem['quantity'] as int,
      );
    }
    for (final entry in quantitiesByProduct.entries) {
      await repository.releaseCancellationStock(
        orderId,
        entry.key,
        entry.value,
      );
    }
    final couponCode = cancelled['couponCode'];
    if (couponCode is String) {
      await repository.releaseCancellationCouponUse(orderId, couponCode);
    }
    await repository.completeReservationRelease(
      orderId,
      DateTime.now().toUtc(),
    );
    return {
      'order': _publicOrder({
        ...cancelled,
        'status': 'cancelled',
        'reservationsReleased': true,
        'reservationReleaseState': 'complete',
      }),
    };
  }

  /// Lists shipment events for one owned order.
  Future<Map<String, Object?>> tracking(
    ObjectId userId,
    ObjectId orderId,
  ) async {
    final repository = await _repositoryProvider();
    final order = await repository.findOwnedOrder(userId, orderId);
    if (order == null) _throwOrderNotFound();
    final events = await repository.findTrackingEvents(orderId);
    return {
      'orderId': orderId.oid,
      'status': order['status'],
      'data': events.map(_publicTrackingEvent).toList(),
    };
  }

  /// Applies a trusted fulfillment transition and records its tracking event.
  Future<Map<String, Object?>> updateTracking({
    required ObjectId orderId,
    required String status,
    required String message,
    String? location,
  }) async {
    final repository = await _repositoryProvider();
    final order = await repository.findOrder(orderId);
    if (order == null) _throwOrderNotFound();
    final currentStatus = order['status'];
    const transitions = {
      'awaiting_fulfillment': 'processing',
      'processing': 'shipped',
      'shipped': 'in_transit',
      'in_transit': 'delivered',
    };
    if (currentStatus is! String || transitions[currentStatus] != status) {
      throw const ApiException(
        statusCode: HttpStatus.conflict,
        code: 'invalid_order_transition',
        message: 'The requested order status transition is not allowed.',
      );
    }
    final now = DateTime.now().toUtc();
    if (!await repository.updateOrderStatus(
      orderId,
      currentStatus,
      status,
      now,
    )) {
      throw const ApiException(
        statusCode: HttpStatus.conflict,
        code: 'order_status_changed',
        message: 'The order status changed before this update was applied.',
      );
    }
    final userId = order['userId'];
    if (userId is! ObjectId) {
      throw StateError('Stored order ownership is invalid.');
    }
    await repository.insertTrackingEvent({
      'orderId': orderId,
      'userId': userId,
      'status': status,
      'message': message.trim(),
      if (location != null) 'location': location.trim(),
      'occurredAt': now,
      'createdAt': now,
    });
    return {
      'orderId': orderId.oid,
      'status': status,
      'message': message.trim(),
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      'occurredAt': now,
    };
  }

  static Map<String, Object?> _publicOrder(Map<String, dynamic> order) {
    final id = order['_id'];
    if (id is! ObjectId) throw StateError('Stored order ID is invalid.');
    const fields = {
      'orderNumber',
      'status',
      'items',
      'addressSnapshot',
      'shippingSnapshot',
      'subtotalMinor',
      'discountMinor',
      'shippingMinor',
      'totalMinor',
      'currency',
      'couponCode',
      'createdAt',
      'updatedAt',
      'paidAt',
    };
    return {
      'id': id.oid,
      for (final field in fields)
        if (order.containsKey(field)) field: order[field],
    };
  }

  static Map<String, Object?> _publicTrackingEvent(
    Map<String, dynamic> event,
  ) {
    final id = event['_id'];
    return {
      if (id is ObjectId) 'id': id.oid,
      'status': event['status'],
      'message': event['message'],
      'location': event['location'],
      'occurredAt': event['occurredAt'],
    };
  }

  static Never _throwOrderNotFound() {
    throw const ApiException(
      statusCode: HttpStatus.notFound,
      code: 'order_not_found',
      message: 'The order could not be found.',
    );
  }
}
