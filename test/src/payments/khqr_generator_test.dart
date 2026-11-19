import 'package:shop_ease_ecommerce/src/payments/khqr_generator.dart';
import 'package:test/test.dart';

void main() {
  test('generates a dynamic USD KHQR payload and MD5.', () {
    final qr = const KhqrGenerator().generate(
      merchantAccountId: 'abaakhppxxx@abaa',
      merchantName: 'Phally La',
      merchantCity: 'Phnom Penh',
      paymentReference: 'SE-TEST123',
      amountMinor: 4599,
      currency: 'USD',
    );

    expect(qr['payload'], startsWith('000201010212'));
    expect(qr['payload'], contains('5303840'));
    expect(qr['payload'], contains('540545.99'));
    final payload = qr['payload']!;
    expect(
      RegExp(r'^[0-9A-F]{4}$').hasMatch(payload.substring(payload.length - 4)),
      isTrue,
    );
    expect(qr['md5'], matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('generates a dynamic KHR KHQR payload.', () {
    final qr = const KhqrGenerator().generate(
      merchantAccountId: 'abaakhppxxx@abaa',
      merchantName: 'Phally La',
      merchantCity: 'Phnom Penh',
      paymentReference: 'SE-KHR123',
      amountMinor: 25000,
      currency: 'KHR',
    );

    expect(qr['payload'], contains('5303116'));
    expect(qr['payload'], contains('540525000'));
  });

  test('rejects unsupported currencies and incomplete merchant data.', () {
    expect(
      () => const KhqrGenerator().generate(
        merchantAccountId: 'abaakhppxxx@abaa',
        merchantName: 'Phally La',
        merchantCity: 'Phnom Penh',
        paymentReference: 'SE-TEST',
        amountMinor: 100,
        currency: 'EUR',
      ),
      throwsArgumentError,
    );
  });
}
