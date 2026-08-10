import 'package:http/http.dart' as http;

import 'errors.dart';
import 'http/transport.dart';
import 'runtime/request_runtime.dart';
import 'session/session_store.dart';

final _merchantSlugPattern = RegExp(r'^[a-z0-9-]+$');

/// A typed client for the direct public Crave Storefront API.
final class CraveStorefrontClient {
  /// Creates a Storefront client isolated to one merchant.
  CraveStorefrontClient({
    required Uri baseUri,
    required String merchantSlug,
    StorefrontCustomerTokenProvider? customerTokenProvider,
    StorefrontSessionStore? sessionStore,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
    StorefrontIdempotencyKeyGenerator? idempotencyKeyGenerator,
  })  : merchantSlug = _validateMerchantSlug(merchantSlug),
        sessionStore = sessionStore ?? InMemoryStorefrontSessionStore(),
        idempotencyKeyGenerator =
            idempotencyKeyGenerator ?? StorefrontIdempotencyKeyGenerator(),
        _transport = StorefrontTransport(
          baseUri: baseUri,
          client: httpClient,
          customerTokenProvider: customerTokenProvider,
          defaultTimeout: timeout,
        );

  final StorefrontTransport _transport;

  /// Canonical API origin.
  Uri get baseUri => _transport.baseUri;

  /// Merchant slug used for session isolation.
  final String merchantSlug;

  /// Caller-owned or ephemeral cart session storage.
  final StorefrontSessionStore sessionStore;

  /// Cryptographically strong request-key generator.
  final StorefrontIdempotencyKeyGenerator idempotencyKeyGenerator;

  /// Releases resources owned by this client.
  void close() => _transport.close();
}

String _validateMerchantSlug(String value) {
  if (value != value.trim() || !_merchantSlugPattern.hasMatch(value)) {
    throw const StorefrontConfigurationException(
      'merchantSlug must contain only lowercase letters, numbers, and hyphens.',
    );
  }
  return value;
}
