import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/orders/order_repository.dart';
import 'package:shop_ease_ecommerce/src/orders/order_service.dart';
import 'package:test/test.dart';

class _MemoryOrderRepository extends Mock implements OrderRepository {
  _MemoryOrderRepository(this.order);

  final Map<String, dynamic> order;
  final Set<String> releasedStockKeys = {};
  final Set<ObjectId> releasedCouponOrders = {};
  int stockUnitsReleased = 0;
  bool failCouponReleaseOnce = false;

  @override
  Future<Map<String, dynamic>?> findOwnedOrder(
    ObjectId userId,
    ObjectId orderId,
  ) async {
    if (order['_id'] != orderId || order['userId'] != userId) return null;
    return order;
  }

  @override
  Future<Map<String, dynamic>?> cancelOrder(
    ObjectId userId,
    ObjectId orderId,
    DateTime now,
  ) async {
    if (await findOwnedOrder(userId, orderId) == null ||
        order['status'] != 'awaiting_fulfillment') {
      return null;
    }
    order
      ..['status'] = 'cancelled'
      ..['reservationReleaseState'] = 'pending';
    return order;
  }

  @override
  Future<void> releaseCancellationStock(
    ObjectId orderId,
    ObjectId productId,
    int quantity,
  ) async {
    if (releasedStockKeys.add('$orderId:$productId')) {
      stockUnitsReleased += quantity;
    }
  }

  @override
  Future<void> releaseCancellationCouponUse(
    ObjectId orderId,
    String code,
  ) async {
    if (failCouponReleaseOnce) {
      failCouponReleaseOnce = false;
      throw StateError('Simulated coupon update failure.');
    }
    releasedCouponOrders.add(orderId);
  }

  @override
  Future<void> completeReservationRelease(
    ObjectId orderId,
    DateTime now,
  ) async {
    order
      ..['reservationReleaseState'] = 'complete'
      ..['reservationsReleased'] = true;
  }
}

void main() {
  group('OrderService.cancel', () {
    late ObjectId userId;
    late ObjectId orderId;
    late ObjectId productId;
    late _MemoryOrderRepository repository;
    late OrderService service;

    setUp(() {
      userId = ObjectId();
      orderId = ObjectId();
      productId = ObjectId();
      repository = _MemoryOrderRepository({
        '_id': orderId,
        'userId': userId,
        'status': 'awaiting_fulfillment',
        'items': [
          {'productId': productId, 'quantity': 2},
          {'productId': productId, 'quantity': 1},
        ],
        'couponCode': 'WELCOME',
      });
      service = OrderService(() async => repository);
    });

    test('releases all reservations and returns a cancelled order.', () async {
      final result = await service.cancel(userId, orderId);

      expect((result['order']! as Map)['status'], 'cancelled');
      expect(repository.stockUnitsReleased, 3);
      expect(repository.releasedCouponOrders, contains(orderId));
      expect(repository.order['reservationReleaseState'], 'complete');
    });

    test('retries a partial release without releasing stock twice.', () async {
      repository.failCouponReleaseOnce = true;

      await expectLater(
        service.cancel(userId, orderId),
        throwsA(isA<StateError>()),
      );
      expect(repository.order['reservationReleaseState'], 'pending');
      expect(repository.stockUnitsReleased, 3);

      final result = await service.cancel(userId, orderId);

      expect((result['order']! as Map)['status'], 'cancelled');
      expect(repository.stockUnitsReleased, 3);
      expect(repository.releasedCouponOrders, contains(orderId));
      expect(repository.order['reservationReleaseState'], 'complete');
    });

    test(
      'does not cancel an order while fulfillment is in progress.',
      () async {
        repository.order['status'] = 'shipped';

        await expectLater(
          service.cancel(userId, orderId),
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              'code',
              'order_not_cancellable',
            ),
          ),
        );
        expect(repository.stockUnitsReleased, 0);
      },
    );
  });
}
