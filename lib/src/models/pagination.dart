/// Validated pagination input and response metadata.
class Pagination {
  /// Creates pagination after its bounds have been validated.
  const Pagination({required this.page, required this.limit});

  /// Parses one-based page and bounded page-size query parameters.
  factory Pagination.parse(Map<String, String> parameters) {
    final page = _parseInteger(parameters, 'page', fallback: 1);
    final limit = _parseInteger(parameters, 'limit', fallback: 20);
    if (page < 1 || page > 100000) {
      throw const FormatException('page must be between 1 and 100000.');
    }
    if (limit < 1 || limit > 100) {
      throw const FormatException('limit must be between 1 and 100.');
    }
    return Pagination(page: page, limit: limit);
  }

  /// One-based page number.
  final int page;

  /// Maximum number of entries in one page.
  final int limit;

  /// Number of matching entries to skip.
  int get offset => (page - 1) * limit;

  /// Builds page metadata for an item count.
  Map<String, Object> metadata(int total) => {
    'page': page,
    'limit': limit,
    'total': total,
    'totalPages': total == 0 ? 0 : (total + limit - 1) ~/ limit,
  };

  static int _parseInteger(
    Map<String, String> parameters,
    String name, {
    required int fallback,
  }) {
    final value = parameters[name];
    if (value == null) return fallback;
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw FormatException('$name must be an integer.');
    }
    return parsed;
  }
}
