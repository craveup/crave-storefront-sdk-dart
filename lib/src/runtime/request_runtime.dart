import 'dart:convert';
import 'dart:math';

import '../cancellation.dart';

final _revisionEtagPattern = RegExp(r'^(?:W/)?"([a-z]+)-(\d+)"$');

/// Returns a cart revision from a strong or weak Storefront ETag.
int? parseCartRevision(String? etag) {
  return _parseResourceRevision(etag, 'cart');
}

/// Returns an address revision from a strong or weak Storefront ETag.
int? parseAddressRevision(String? etag) =>
    _parseResourceRevision(etag, 'address');

int? _parseResourceRevision(String? etag, String resource) {
  final match = etag == null ? null : _revisionEtagPattern.firstMatch(etag);
  if (match == null || match.group(1) != resource) {
    return null;
  }
  return int.tryParse(match.group(2)!);
}

/// Generates cryptographically strong Storefront idempotency keys.
final class StorefrontIdempotencyKeyGenerator {
  /// Creates a key generator.
  StorefrontIdempotencyKeyGenerator({Random? random})
      : _random = random ?? Random.secure();

  final Random _random;

  /// Returns a new key containing only characters accepted by the API.
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
