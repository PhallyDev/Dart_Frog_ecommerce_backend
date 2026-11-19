import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Generates an EMV-compatible dynamic KHQR payload and its MD5 reference.
class KhqrGenerator {
  const KhqrGenerator();

  Map<String, String> generate({
    required String merchantAccountId,
    required String merchantName,
    required String merchantCity,
    required String paymentReference,
    required int amountMinor,
    required String currency,
  }) {
    if (!const {'USD', 'KHR'}.contains(currency)) {
      throw ArgumentError.value(currency, 'currency');
    }
    if (amountMinor < 1) throw ArgumentError.value(amountMinor, 'amountMinor');
    if (merchantAccountId.isEmpty ||
        merchantName.isEmpty ||
        merchantCity.isEmpty ||
        paymentReference.isEmpty) {
      throw const FormatException('KHQR merchant configuration is incomplete.');
    }

    final amount = currency == 'USD'
        ? (amountMinor / 100).toStringAsFixed(2)
        : amountMinor.toString();
    final merchantSubtags = _fields({
      '00': 'A000000677010111',
      '01': merchantAccountId,
      '02': paymentReference,
    });
    final additionalSubtags = _fields({'01': paymentReference});
    var payload =
        '${_field('00', '01')}'
        '${_field('01', '12')}'
        '${_field('29', merchantSubtags)}'
        '${_field('52', '0000')}'
        '${_field('53', currency == 'USD' ? '840' : '116')}'
        '${_field('54', amount)}'
        '${_field('58', 'KH')}'
        '${_field('59', merchantName)}'
        '${_field('60', merchantCity)}'
        '${_field('62', additionalSubtags)}';
    payload = '${payload}6304';
    payload = '$payload${_crc16(payload)}';
    return {
      'payload': payload,
      'md5': md5.convert(utf8.encode(payload)).toString(),
    };
  }

  static String _fields(Map<String, String> values) =>
      values.entries.map((entry) => _field(entry.key, entry.value)).join();

  static String _field(String tag, String value) {
    final length = value.length;
    if (tag.length != 2 || length > 99) {
      throw FormatException('Invalid KHQR EMV field length.');
    }
    return '$tag${length.toString().padLeft(2, '0')}$value';
  }

  static String _crc16(String value) {
    var crc = 0xffff;
    for (final byte in ascii.encode(value)) {
      crc ^= byte << 8;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xffff
            : (crc << 1) & 0xffff;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
