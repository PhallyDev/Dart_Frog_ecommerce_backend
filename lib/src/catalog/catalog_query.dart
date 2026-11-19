import 'package:shop_ease_ecommerce/src/models/pagination.dart';

/// Validated public product-list filters.
class CatalogQuery {
  /// Creates a query after its input has been validated.
  const CatalogQuery({
    required this.pagination,
    required this.sort,
    this.search,
    this.categorySlug,
    this.minimumPriceMinor,
    this.maximumPriceMinor,
    this.inStockOnly = false,
  });

  /// Parses supported product query parameters.
  factory CatalogQuery.parse(Map<String, String> parameters) {
    const supported = {
      'q',
      'category',
      'sort',
      'page',
      'limit',
      'minPrice',
      'maxPrice',
      'inStock',
    };
    final unknown = parameters.keys.toSet().difference(supported);
    if (unknown.isNotEmpty) {
      throw FormatException(
        'Unsupported query parameter: ${unknown.first}.',
      );
    }

    final search = parameters['q']?.trim();
    if (search != null && search.length > 100) {
      throw const FormatException('q must not exceed 100 characters.');
    }
    final category = parameters['category']?.trim();
    if (category != null &&
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$').hasMatch(category)) {
      throw const FormatException('category has an invalid format.');
    }

    final minimum = _parsePrice(parameters, 'minPrice');
    final maximum = _parsePrice(parameters, 'maxPrice');
    if (minimum != null && maximum != null && minimum > maximum) {
      throw const FormatException('minPrice must not exceed maxPrice.');
    }

    final inStockValue = parameters['inStock'];
    if (inStockValue != null &&
        inStockValue != 'true' &&
        inStockValue != 'false') {
      throw const FormatException('inStock must be true or false.');
    }

    final requestedSort = parameters['sort'];
    final sort =
        requestedSort ??
        (search != null && search.isNotEmpty ? 'relevance' : 'newest');
    if (!const {
      'relevance',
      'price_asc',
      'price_desc',
      'name_asc',
      'newest',
      'rating_desc',
    }.contains(sort)) {
      throw const FormatException('sort is not supported.');
    }
    if (sort == 'relevance' && (search == null || search.isEmpty)) {
      throw const FormatException('sort=relevance requires a non-empty q.');
    }

    return CatalogQuery(
      pagination: Pagination.parse(parameters),
      sort: sort,
      search: search == null || search.isEmpty ? null : search,
      categorySlug: category,
      minimumPriceMinor: minimum,
      maximumPriceMinor: maximum,
      inStockOnly: inStockValue == 'true',
    );
  }

  /// Pagination for the requested page.
  final Pagination pagination;

  /// Search phrase, when supplied.
  final String? search;

  /// Category slug, when supplied.
  final String? categorySlug;

  /// Inclusive lower bound in minor currency units.
  final int? minimumPriceMinor;

  /// Inclusive upper bound in minor currency units.
  final int? maximumPriceMinor;

  /// Whether to include only products with positive stock.
  final bool inStockOnly;

  /// Validated sort order.
  final String sort;

  static int? _parsePrice(Map<String, String> parameters, String name) {
    final value = parameters[name];
    if (value == null) return null;
    if (!RegExp(r'^\d{1,8}(?:\.\d{1,2})?$').hasMatch(value)) {
      throw FormatException(
        '$name must be a non-negative price with at most '
        'two decimal places.',
      );
    }
    final parts = value.split('.');
    final whole = int.parse(parts.first);
    final fraction = parts.length == 1
        ? 0
        : int.parse(parts.last.padRight(2, '0'));
    return whole * 100 + fraction;
  }
}
