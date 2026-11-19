import 'package:mongo_dart/mongo_dart.dart';

/// Common MongoDB document identity and UTC timestamps.
class DocumentMetadata {
  /// Creates metadata for an existing MongoDB document.
  const DocumentMetadata({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates new metadata using the current UTC time.
  factory DocumentMetadata.create({ObjectId? id, DateTime? now}) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return DocumentMetadata(
      id: id ?? ObjectId(),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  /// Deserializes shared metadata from a MongoDB document.
  factory DocumentMetadata.fromMap(Map<String, Object?> document) {
    final id = document['_id'];
    final createdAt = document['createdAt'];
    final updatedAt = document['updatedAt'];
    if (id is! ObjectId || createdAt is! DateTime || updatedAt is! DateTime) {
      throw const FormatException('Invalid MongoDB document metadata.');
    }
    return DocumentMetadata(
      id: id,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
  }

  /// MongoDB document identifier.
  final ObjectId id;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC last-update timestamp.
  final DateTime updatedAt;

  /// Serializes the shared metadata fields to BSON-compatible values.
  Map<String, Object> toMap() => {
    '_id': id,
    'createdAt': createdAt.toUtc(),
    'updatedAt': updatedAt.toUtc(),
  };
}
