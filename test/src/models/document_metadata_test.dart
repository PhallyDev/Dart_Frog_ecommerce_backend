import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/models/document_metadata.dart';
import 'package:test/test.dart';

void main() {
  test('round-trips ObjectId and UTC timestamps.', () {
    final metadata = DocumentMetadata.create(
      id: ObjectId.fromHexString('507f1f77bcf86cd799439011'),
      now: DateTime.utc(2026, 10, 27, 12),
    );

    final decoded = DocumentMetadata.fromMap(metadata.toMap());

    expect(decoded.id, metadata.id);
    expect(decoded.createdAt, DateTime.utc(2026, 10, 27, 12));
    expect(decoded.updatedAt, DateTime.utc(2026, 10, 27, 12));
  });

  test('rejects documents with invalid metadata types.', () {
    expect(
      () => DocumentMetadata.fromMap({
        '_id': 'not-an-object-id',
        'createdAt': DateTime.utc(2026),
        'updatedAt': DateTime.utc(2026),
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
