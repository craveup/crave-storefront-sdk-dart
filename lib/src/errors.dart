/// Base type for failures deliberately surfaced by the Storefront SDK.
sealed class StorefrontException implements Exception {
  /// Creates an SDK exception.
  const StorefrontException();
}

/// Indicates invalid SDK configuration or invalid request input.
final class StorefrontConfigurationException extends StorefrontException {
  /// Creates a configuration exception with a safe developer-facing message.
  const StorefrontConfigurationException(this.message);

  /// A message that never includes request credentials or payload data.
  final String message;

  @override
  String toString() => 'StorefrontConfigurationException: $message';
}

/// Indicates that the Storefront API returned a non-success status.
final class StorefrontApiException extends StorefrontException {
  /// Creates a safe API exception.
  const StorefrontApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    required this.method,
    required this.routeTemplate,
    this.requestId,
    this.details,
  });

  /// HTTP status returned by the API.
  final int statusCode;

  /// Stable machine-readable API error code, or `HTTP_ERROR`.
  final String code;

  /// Redaction-safe summary suitable for developer diagnostics.
  final String message;

  /// Correlation ID returned by the API, when available.
  final String? requestId;

  /// Sanitized structured detail such as invalid field paths.
  final Map<String, Object?>? details;

  /// HTTP method for the failed operation.
  final String method;

  /// Parameterized route template; never a resolved URL.
  final String routeTemplate;

  /// Whether the failure represents a stale cart revision.
  bool get isCartConflict => code == 'CART_CONFLICT';

  @override
  String toString() => 'StorefrontApiException($statusCode, $code): $message '
      '[$method $routeTemplate${requestId == null ? '' : ', requestId=$requestId'}]';
}

/// Indicates that a Storefront request exceeded its configured deadline.
final class StorefrontTimeoutException extends StorefrontException {
  /// Creates a timeout exception.
  const StorefrontTimeoutException({
    required this.method,
    required this.routeTemplate,
    required this.timeout,
  });

  /// HTTP method for the timed-out operation.
  final String method;

  /// Parameterized route template; never a resolved URL.
  final String routeTemplate;

  /// Deadline that elapsed.
  final Duration timeout;

  @override
  String toString() =>
      'StorefrontTimeoutException: $method $routeTemplate exceeded '
      '${timeout.inMilliseconds}ms';
}

/// Indicates that the caller cancelled a Storefront request.
final class StorefrontRequestCancelledException extends StorefrontException {
  /// Creates a cancellation exception.
  const StorefrontRequestCancelledException({
    required this.method,
    required this.routeTemplate,
  });

  /// HTTP method for the cancelled operation.
  final String method;

  /// Parameterized route template; never a resolved URL.
  final String routeTemplate;

  @override
  String toString() =>
      'StorefrontRequestCancelledException: $method $routeTemplate';
}

/// Indicates a network failure before a valid API response was received.
final class StorefrontNetworkException extends StorefrontException {
  /// Creates a redaction-safe network exception.
  const StorefrontNetworkException({
    required this.method,
    required this.routeTemplate,
  });

  /// HTTP method for the failed operation.
  final String method;

  /// Parameterized route template; never a resolved URL.
  final String routeTemplate;

  @override
  String toString() => 'StorefrontNetworkException: $method $routeTemplate';
}

/// Indicates that a successful API response did not match its JSON contract.
final class StorefrontDecodingException extends StorefrontException {
  /// Creates a redaction-safe response decoding exception.
  const StorefrontDecodingException({
    required this.method,
    required this.routeTemplate,
  });

  /// HTTP method for the operation.
  final String method;

  /// Parameterized route template; never a resolved URL.
  final String routeTemplate;

  @override
  String toString() => 'StorefrontDecodingException: $method $routeTemplate';
}
