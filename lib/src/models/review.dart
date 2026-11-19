import 'package:mongo_dart/mongo_dart.dart';

/// Public review content; private user and purchase fields are never exposed.
class Review {
  /// Creates a review response model.
  const Review({
    required this.id,
    required this.rating,
    required this.createdAt,
    this.title,
    this.body,
    this.reviewerName,
  });

  /// Reads a review document from MongoDB.
  factory Review.fromDocument(Map<String, dynamic> document) {
    final id = document['_id'];
    final rating = document['rating'];
    final createdAt = document['createdAt'];
    if (id is! ObjectId ||
        rating is! num ||
        rating < 1 ||
        rating > 5 ||
        rating != rating.toInt() ||
        createdAt is! DateTime) {
      throw const FormatException('Invalid review document.');
    }
    return Review(
      id: id,
      rating: rating.toInt(),
      createdAt: createdAt.toUtc(),
      title: document['title'] as String?,
      body: document['body'] as String?,
      reviewerName: document['reviewerName'] as String?,
    );
  }

  /// MongoDB review identifier as a hex string.
  final ObjectId id;

  /// Integer rating from one to five.
  final int rating;

  /// Optional review title.
  final String? title;

  /// Optional review text.
  final String? body;

  /// Optional public reviewer display name.
  final String? reviewerName;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// Converts this review into an API-safe JSON object.
  Map<String, Object?> toJson() => {
    'id': id.oid,
    'rating': rating,
    if (title != null) 'title': title,
    if (body != null) 'body': body,
    if (reviewerName != null) 'reviewerName': reviewerName,
    'createdAt': createdAt.toIso8601String(),
  };
}
