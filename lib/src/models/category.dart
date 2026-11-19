import 'package:mongo_dart/mongo_dart.dart';

/// Public category data returned by catalog endpoints.
class Category {
  /// Creates a category response model.
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.sortOrder,
    this.description,
    this.imageUrl,
  });

  /// Reads a category document from MongoDB.
  factory Category.fromDocument(Map<String, dynamic> document) {
    final id = document['_id'];
    final name = document['name'];
    final slug = document['slug'];
    final sortOrder = document['sortOrder'];
    if (id is! ObjectId ||
        name is! String ||
        slug is! String ||
        sortOrder is! num) {
      throw const FormatException('Invalid category document.');
    }
    return Category(
      id: id,
      name: name,
      slug: slug,
      sortOrder: sortOrder.toInt(),
      description: document['description'] as String?,
      imageUrl: document['imageUrl'] as String?,
    );
  }

  /// MongoDB category identifier as a hex string.
  final ObjectId id;

  /// Display name.
  final String name;

  /// URL-safe category slug.
  final String slug;

  /// Optional category description.
  final String? description;

  /// Optional category image URL.
  final String? imageUrl;

  /// Display ordering value.
  final int sortOrder;

  /// Converts this category into an API-safe JSON object.
  Map<String, Object?> toJson() => {
    'id': id.oid,
    'name': name,
    'slug': slug,
    if (description != null) 'description': description,
    if (imageUrl != null) 'imageUrl': imageUrl,
    'sortOrder': sortOrder,
  };
}
