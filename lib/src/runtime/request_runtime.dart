import 'dart:convert';
import 'dart:math';

import '../cancellation.dart';

final _cartEtagPattern = RegExp(r'^(?:W/)?"cart-(\d+)"$');

/// Returns a cart revision from a strong or weak Storefront ETag.
int? parseCartRevision(String? etag) {
  final match = etag == null ? null : _cartEtagPattern.firstMatch(etag);
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// Generates cryptographically strong Storefront idempotency keys.
final class StorefrontIdempotencyKeyGenerator {
  /// Creates a key generator.
  StorefrontIdempotencyKeyGenerator({Random? random})
      : _random = random ?? Random.secure();

  final Random _random;

  /// Returns a new 147-character-safe key.
  String next() {
    final bytes = List<int>.generate(18, (_) => _random.nextInt(256));
    return 'sf_${base64Url.encode(bytes).replaceAll('=', '')}';
  }
}

/// Per-call transport and concurrency controls.
final class StorefrontRequestOptions {
  /// Creates request options.
  const StorefrontRequestOptions({
    this.timeout,
    this.cancellationToken,
    this.idempotencyKey,
    this.revision,
  });

  /// Overrides the client request deadline.
  final Duration? timeout;

  /// Cancels the in-flight request when signalled.
  final StorefrontCancellationToken? cancellationToken;

  /// Caller-stable key for an idempotent operation.
  final String? idempotencyKey;

  /// Caller-supplied resource revision override.
  final int? revision;
}
