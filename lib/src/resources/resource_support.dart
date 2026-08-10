import '../cancellation.dart';
import '../errors.dart';
import '../runtime/request_runtime.dart';

/// Converts a decoded JSON value to an object map.
Map<String, Object?> decodeJsonObject(Object? value) =>
    (value as Map).cast<String, Object?>();

/// Converts a decoded JSON value to a list of object maps.
List<Map<String, Object?>> decodeJsonObjectList(Object? value) =>
    (value as List)
        .map((item) => (item as Map).cast<String, Object?>())
        .toList(growable: false);

/// Transport values projected from public request options.
final class ResourceRequestOptions {
  /// Creates a transport projection of [source].
  const ResourceRequestOptions(this.source);

  /// Caller-supplied public request options, when present.
  final StorefrontRequestOptions? source;

  /// Per-request timeout override.
  Duration? get timeout => source?.timeout;

  /// Per-request cancellation signal.
  StorefrontCancellationToken? get cancellationToken =>
      source?.cancellationToken;

  /// Caller-stable idempotency key, when supplied.
  String? get idempotencyKey => source?.idempotencyKey;

  /// Caller-supplied resource revision, when supplied.
  int? get revision => source?.revision;
}

/// One monotonic timeout and cancellation budget for a public SDK operation.
final class StorefrontOperationContext {
  /// Creates an operation budget before any caller-owned dependency is read.
  StorefrontOperationContext({
    required Duration defaultTimeout,
    required this.method,
    required this.routeTemplate,
    StorefrontRequestOptions? options,
  })  : _timeout = options?.timeout ?? defaultTimeout,
        cancellationToken = options?.cancellationToken {
    if (_timeout <= Duration.zero) {
      throw const StorefrontConfigurationException(
        'The request timeout must be greater than zero.',
      );
    }
    _clock.start();
  }

  final Duration _timeout;
  final Stopwatch _clock = Stopwatch();

  /// HTTP method for typed failures.
  final String method;

  /// Parameterized route template for typed failures.
  final String routeTemplate;

  /// Caller cancellation signal shared with the transport.
  final StorefrontCancellationToken? cancellationToken;

  /// Time remaining before the complete SDK operation deadline.
  Duration get remaining {
    final value = _timeout - _clock.elapsed;
    if (value <= Duration.zero) {
      throw StorefrontTimeoutException(
        method: method,
        routeTemplate: routeTemplate,
        timeout: _timeout,
      );
    }
    return value;
  }

  /// Waits for any operation phase within the same deadline/cancellation.
  Future<T> wait<T>(Future<T> future) {
    if (cancellationToken?.isCancelled ?? false) {
      return Future<T>.error(
        StorefrontRequestCancelledException(
          method: method,
          routeTemplate: routeTemplate,
        ),
      );
    }
    final timeout = remaining;
    return Future.any<T>([
      future,
      Future<T>.delayed(
        timeout,
        () => throw StorefrontTimeoutException(
          method: method,
          routeTemplate: routeTemplate,
          timeout: _timeout,
        ),
      ),
      if (cancellationToken != null)
        cancellationToken!.whenCancelled.then<T>(
          (_) => throw StorefrontRequestCancelledException(
            method: method,
            routeTemplate: routeTemplate,
          ),
        ),
    ]);
  }

  /// Waits for caller-owned session storage and redacts adapter failures.
  Future<T> waitForSession<T>(
    Future<T> future, {
    required bool operationMayHaveSucceeded,
    String? retryIdempotencyKey,
  }) async {
    try {
      return await wait(future);
    } on StorefrontTimeoutException catch (error) {
      if (retryIdempotencyKey == null) {
        rethrow;
      }
      throw StorefrontTimeoutException(
        method: error.method,
        routeTemplate: error.routeTemplate,
        timeout: error.timeout,
        retryIdempotencyKey: retryIdempotencyKey,
      );
    } on StorefrontRequestCancelledException catch (error) {
      if (retryIdempotencyKey == null) {
        rethrow;
      }
      throw StorefrontRequestCancelledException(
        method: error.method,
        routeTemplate: error.routeTemplate,
        retryIdempotencyKey: retryIdempotencyKey,
      );
    } on StorefrontException {
      rethrow;
    } on Object {
      throw StorefrontSessionException(
        method: method,
        routeTemplate: routeTemplate,
        operationMayHaveSucceeded: operationMayHaveSucceeded,
        retryIdempotencyKey: retryIdempotencyKey,
      );
    }
  }
}
