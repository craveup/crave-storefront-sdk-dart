import 'package:http/http.dart' as http;

import 'auth.dart';
import 'errors.dart';
import 'http/transport.dart';
import 'resources/catalog_resources.dart';
import 'resources/checkout_loyalty_resources.dart';
import 'resources/customer_resources.dart';
import 'resources/ordering_cart_resources.dart';
import 'runtime/cart_session_runtime.dart';
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
        ) {
    merchants = MerchantsClient(_transport, this.merchantSlug);
    locations = LocationsClient(_transport);
    menus = MenusClient(_transport);
    products = ProductsClient(_transport);
    _cartRuntime = CartSessionRuntime(
      apiOrigin: _transport.baseUri,
      merchantSlug: this.merchantSlug,
      sessionStore: this.sessionStore,
      idempotencyKeyGenerator: this.idempotencyKeyGenerator,
    );
    orderingSessions = OrderingSessionsClient(_transport, _cartRuntime);
    analyticsEvents = AnalyticsEventsClient(_transport, _cartRuntime);
    carts = CartsClient(_transport, _cartRuntime);
    customers = CustomersClient(
      _transport,
      this.merchantSlug,
      this.idempotencyKeyGenerator,
    );
    checkout = CheckoutClient(_transport, _cartRuntime);
    ratings = RatingsClient(_transport, _cartRuntime);
    receipts = ReceiptsClient(_transport);
    loyalty = LoyaltyClient(_transport, _cartRuntime);
  }

  final StorefrontTransport _transport;
  late final CartSessionRuntime _cartRuntime;

  /// Published merchant discovery operations.
  late final MerchantsClient merchants;

  /// Published location and availability operations.
  late final LocationsClient locations;

  /// Published location-menu operations.
  late final MenusClient menus;

  /// Published product and modifier-tree operations.
  late final ProductsClient products;

  /// Ordering-session bootstrap and resume operations.
  late final OrderingSessionsClient orderingSessions;

  /// Best-effort Storefront analytics operations.
  late final AnalyticsEventsClient analyticsEvents;

  /// Cart, item, discount, fulfillment, and claim operations.
  late final CartsClient carts;

  /// Customer identity, order, address, and saved-payment operations.
  late final CustomersClient customers;

  /// Checkout handoff, payment-intent, and order-result operations.
  late final CheckoutClient checkout;

  /// Post-checkout customer rating operations.
  late final RatingsClient ratings;

  /// Capability- or customer-authorized receipt operations.
  late final ReceiptsClient receipts;

  /// Customer loyalty quote, redemption, ledger, and claim operations.
  late final LoyaltyClient loyalty;

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
