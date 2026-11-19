/// A safe, client-facing error with an HTTP status and stable error code.
class ApiException implements Exception {
  /// Creates a safe client-facing API error.
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.headers = const {},
  });

  /// HTTP response status for this error.
  final int statusCode;

  /// Machine-readable error identifier.
  final String code;

  /// Safe message suitable for an API response.
  final String message;

  /// Optional safe response headers, such as `Retry-After`.
  final Map<String, Object> headers;
}
