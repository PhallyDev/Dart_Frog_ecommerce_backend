import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/config/app_config.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/orders/order_repository.dart';
import 'package:shop_ease_ecommerce/src/payments/bakong_api_client.dart';
import 'package:shop_ease_ecommerce/src/payments/payment_repository.dart';
import 'package:shop_ease_ecommerce/src/payments/payment_service.dart';
import 'package:test/test.dart';

class _PaymentRepository extends Mock implements PaymentRepository {}

class _OrderRepository extends Mock implements OrderRepository {}

class _BakongClient extends Mock implements BakongApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(ObjectId());
    registerFallbackValue(<String, Object?>{});
  });
  late ObjectId userId;
  late ObjectId orderId;
  late ObjectId paymentId;
  late _PaymentRepository payments;
  late _OrderRepository orders;
  late _BakongClient bakong;
  late PaymentService service;
  late Map<String, dynamic> order;
  late Map<String, dynamic>? payment;

  setUp(() {
    userId = ObjectId();
    orderId = ObjectId();
    paymentId = ObjectId();
    payments = _PaymentRepository();
    orders = _OrderRepository();
    bakong = _BakongClient();
    order = {
      '_id': orderId,
      'userId': userId,
      'orderNumber': 'SE-TEST123',
      'status': 'awaiting_fulfillment',
      'totalMinor': 4599,
      'currency': 'USD',
    };
    payment = null;
    when(() => payments.findByOrder(orderId)).thenAnswer((_) async => payment);
    when(
      () => orders.findOwnedOrder(userId, orderId),
    ).thenAnswer((_) async => order);
    when(() => payments.findOwned(userId, any())).thenAnswer((
      invocation,
    ) async {
      final id = invocation.positionalArguments[1] as ObjectId;
      return payment?['_id'] == id ? payment : null;
    });
    when(() => payments.insert(any())).thenAnswer((invocation) async {
      payment = Map<String, dynamic>.from(
        invocation.positionalArguments.first as Map,
      );
    });
    when(() => payments.expire(any(), any())).thenAnswer((_) async => true);
    when(
      () => payments.cancel(any(), any(), any()),
    ).thenAnswer((_) async => true);
    when(
      () => payments.markOrderPaid(any(), any()),
    ).thenAnswer((_) async => true);
    when(() => payments.claimPaid(any(), any(), any())).thenAnswer((_) async {
      payment
        ?..['status'] = 'PAID'
        ..['paidAt'] = DateTime.now().toUtc();
      return true;
    });
    when(
      () => payments.findByTransactionHash(any()),
    ).thenAnswer((_) async => null);
    when(() => bakong.checkTransactionByMd5(any())).thenAnswer(
      (_) async => {
        'responseCode': 0,
        'responseMessage': 'Success',
        'data': {
          'hash': 'bakong-test-hash',
          'amount': 45.99,
          'currency': 'USD',
          'toAccountId': 'abaakhppxxx@abaa',
          'status': 'SUCCESS',
        },
      },
    );

    service = PaymentService(
      () async => payments,
      () async => orders,
      AppConfig.fromMap({
        'MONGODB_URI': 'mongodb://127.0.0.1:27017/shop_ease_ecommerce',
        'MONGODB_DATABASE': 'shop_ease_ecommerce',
        'BAKONG_TOKEN': 'test-token',
        'BAKONG_MERCHANT_ACCOUNT_ID': 'abaakhppxxx@abaa',
        'BAKONG_MERCHANT_NAME': 'Phally La',
        'BAKONG_MERCHANT_CITY': 'Phnom Penh',
      }),
      bakong,
    );
  });

  test('creates one pending payment using the database order total.', () async {
    final result = await service.create(userId, orderId);
    final resultPayment = result['payment']! as Map;

    expect(resultPayment['orderId'], orderId.oid);
    expect(resultPayment['amountMinor'], 4599);
    expect(resultPayment['currency'], 'USD');
    expect(resultPayment['status'], 'PENDING');
    expect(resultPayment['qrPayload'], isA<String>());
    verify(() => payments.insert(any())).called(1);
  });

  test('rejects creating payment for another user order.', () async {
    when(
      () => orders.findOwnedOrder(userId, orderId),
    ).thenAnswer((_) async => null);

    await expectLater(
      service.create(userId, orderId),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'order_not_found',
        ),
      ),
    );
  });

  test('verifies successful transaction and marks the order paid.', () async {
    await service.create(userId, orderId);
    paymentId = payment!['_id'] as ObjectId;
    payment!['expiresAt'] = DateTime.now().toUtc().add(
      const Duration(minutes: 30),
    );

    final result = await service.verify(userId, paymentId);

    expect((result['payment']! as Map)['status'], 'PAID');
    expect(payment!['status'], 'PAID');
    verify(
      () => payments.claimPaid(paymentId, 'bakong-test-hash', any()),
    ).called(1);
  });
}
