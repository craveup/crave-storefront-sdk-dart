import '../errors.dart';
import '../http/transport.dart';
import '../models/cart.dart';
import '../models/checkout.dart';
import '../models/customer.dart';
import '../models/loyalty.dart';
import '../runtime/cart_session_runtime.dart';
import '../runtime/request_runtime.dart';
import 'cart_resource_support.dart';
import 'resource_support.dart';

final _loyaltyClaimOrderIdPattern = RegExp(r'^[a-fA-F0-9]{24}$');

/// Creates checkout resources for the package facade.
CheckoutClient createCheckoutClient(
  StorefrontTransport transport,
  CartSessionRuntime cartRuntime,
) =>
    CheckoutClient._(transport, cartRuntime);

/// Creates rating resources for the package facade.
RatingsClient createRatingsClient(
  StorefrontTransport transport,
  CartSessionRuntime cartRuntime,
) =>
    RatingsClient._(transport, cartRuntime);

/// Creates receipt resources for the package facade.
ReceiptsClient createReceiptsClient(StorefrontTransport transport) =>
    ReceiptsClient._(transport);

/// Creates loyalty resources for the package facade.
LoyaltyClient createLoyaltyClient(
  StorefrontTransport transport,
  CartSessionRuntime cartRuntime,
) =>
    LoyaltyClient._(transport, cartRuntime);

/// Checkout handoff, payment-intent, and order-result operations.
final class CheckoutClient {
  CheckoutClient._(
    StorefrontTransport transport,
    CartSessionRuntime cartRuntime,
  )   : _transport = transport,
        _cartRuntime = cartRuntime,
        _cartRequests = CartResourceRequests(transport, cartRuntime);

  final StorefrontTransport _transport;
  final CartSessionRuntime _cartRuntime;
  final CartResourceRequests _cartRequests;

  /// Creates or resumes the caller-owned Stripe payment intent for a cart.
  Future<PaymentIntent> createPaymentIntent(
    String locationId,
    String cartId, {
    StorefrontRequestOptions? options,
  }) =>
      _cartRequests.send<PaymentIntent>(
        method: 'POST',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['payment-intent'],
        routeTemplate: '/locations/:locationId/carts/:cartId/payment-intent',
        body: const <String, Object?>{},
        idempotent: true,
        revisionRequired: true,
        persistRevision: true,
        refreshOnConflict: true,
        decoder: (value) => PaymentIntent.fromJson(decodeJsonObject(value)),
        options: options,
      );

  /// Gets the current payment and order-creation state for a cart.
  Future<OrderResult> getOrderResult(
    String locationId,
    String cartId, {
    StorefrontRequestOptions? options,
  }) =>
      _cartRequests.send<OrderResult>(
        method: 'GET',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['order-result'],
        routeTemplate: '/locations/:locationId/carts/:cartId/order-result',
        decoder: (value) => OrderResult.fromJson(decodeJsonObject(value)),
        options: options,
      );

  /// Prepares a short-lived hosted-checkout handoff for a guest cart.
  ///
  /// This operation requires the matching guest cart capability. It never
  /// falls back to the customer JWT provider.
  Future<CheckoutHandoff> prepareHandoff(
    String locationId,
    String cartId, {
    StorefrontRequestOptions? options,
  }) =>
      _cartRequests.send<CheckoutHandoff>(
        method: 'POST',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['checkout-handoffs'],
        routeTemplate: '/locations/:locationId/carts/:cartId/checkout-handoffs',
        authorization: StorefrontAuthorization.cartCapability,
        body: const <String, Object?>{},
        idempotent: true,
        decoder: (value) => CheckoutHandoff.fromJson(decodeJsonObject(value)),
        options: options,
      );

  /// Exchanges a call-scoped handoff capability for an app-owned cart session.
  ///
  /// [options] must contain a caller-stable idempotency key so an interrupted
  /// exchange can be replayed safely without reusing a different key.
  Future<CheckoutExchangeResult> exchangeHandoff(
    String locationId,
    String cartId,
    String handoffToken, {
    required StorefrontRequestOptions options,
  }) async {
    const method = 'POST';
    const routeTemplate =
        '/locations/:locationId/carts/:cartId/checkout-handoffs/exchange';
    final idempotencyKey = options.idempotencyKey;
    if (idempotencyKey == null) {
      throw const StorefrontConfigurationException(
        'A caller-stable idempotency key is required for checkout exchange.',
      );
    }
    final operation = StorefrontOperationContext(
      defaultTimeout: _transport.defaultTimeout,
      method: method,
      routeTemplate: routeTemplate,
      options: options,
    );
    Future<CheckoutExchangeResult> exchange() async {
      final response = await _transport.send<CheckoutExchangeResult>(
        method: method,
        pathSegments: [
          'locations',
          locationId,
          'carts',
          cartId,
          'checkout-handoffs',
          'exchange',
        ],
        routeTemplate: routeTemplate,
        authorization: StorefrontAuthorization.checkoutHandoff,
        checkoutHandoffToken: handoffToken,
        idempotencyKey: idempotencyKey,
        body: const <String, Object?>{},
        decoder: (value) =>
            CheckoutExchangeResult.fromJson(decodeJsonObject(value)),
        timeout: operation.remaining,
        cancellationToken: operation.cancellationToken,
      );
      final result = response.data;
      if (result.merchantSlug != _cartRuntime.merchantSlug ||
          result.cart.locationId != locationId ||
          result.cart.id != cartId) {
        throw StorefrontDecodingException(
          method: method,
          routeTemplate: routeTemplate,
          retryIdempotencyKey: idempotencyKey,
        );
      }
      final etagRevision = parseCartRevision(response.etag);
      if (etagRevision == null || etagRevision != result.cart.revision) {
        throw StorefrontDecodingException(
          method: method,
          routeTemplate: routeTemplate,
          retryIdempotencyKey: idempotencyKey,
        );
      }
      await operation.waitForSession(
        _cartRuntime.capture(
          locationId: locationId,
          cartId: result.cart.id,
          accessToken: result.cartAccessToken,
          revision: etagRevision,
          expiresAt: result.cart.expiresAt == null
              ? null
              : DateTime.tryParse(result.cart.expiresAt!),
        ),
        operationMayHaveSucceeded: true,
        retryIdempotencyKey: idempotencyKey,
      );
      return result;
    }

    return _cartRuntime.serializeCartOperation(
      locationId: locationId,
      cartId: cartId,
      waitForPrevious: operation.wait,
      operation: exchange,
    );
  }
}

/// Post-checkout customer rating operations.
final class RatingsClient {
  RatingsClient._(
    StorefrontTransport transport,
    CartSessionRuntime cartRuntime,
  )   : _cartRuntime = cartRuntime,
        _cartRequests = CartResourceRequests(transport, cartRuntime);

  final CartSessionRuntime _cartRuntime;
  final CartResourceRequests _cartRequests;

  /// Submits a rating for a cart after its payment succeeds.
  Future<RatingResult> submit(
    String locationId,
    String cartId,
    RatingRequest request, {
    StorefrontRequestOptions? options,
  }) =>
      _cartRequests.send<RatingResult>(
        method: 'POST',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['rating'],
        routeTemplate: '/locations/:locationId/carts/:cartId/rating',
        body: request.toJson(),
        idempotent: true,
        decoder: (value) => RatingResult.fromJson(decodeJsonObject(value)),
        afterSuccess: () => _cartRuntime.clear(
          locationId: locationId,
          cartId: cartId,
        ),
        options: options,
      );
}

/// Capability- or customer-authorized receipt operations.
final class ReceiptsClient {
  const ReceiptsClient._(this._transport);

  final StorefrontTransport _transport;

  /// Gets a public order receipt using [receiptToken] or the customer JWT.
  ///
  /// When [receiptToken] is supplied, the customer token provider is not
  /// called and the receipt capability is sent only in `X-Receipt-Token`.
  Future<PublicOrderDetail> get(
    String receiptId, {
    String? receiptToken,
    StorefrontRequestOptions? options,
  }) async {
    final response = await _transport.send<PublicOrderDetail>(
      method: 'GET',
      pathSegments: ['receipts', receiptId],
      routeTemplate: '/receipts/:receiptId',
      authorization: StorefrontAuthorization.receiptOrCustomer,
      receiptToken: receiptToken,
      decoder: (value) => PublicOrderDetail.fromJson(decodeJsonObject(value)),
      timeout: options?.timeout,
      cancellationToken: options?.cancellationToken,
    );
    return response.data;
  }
}

/// Customer loyalty quote, redemption, ledger, and claim operations.
final class LoyaltyClient {
  LoyaltyClient._(
    StorefrontTransport transport,
    CartSessionRuntime cartRuntime,
  )   : _transport = transport,
        _cartRuntime = cartRuntime,
        _cartRequests = CartResourceRequests(transport, cartRuntime);

  final StorefrontTransport _transport;
  final CartSessionRuntime _cartRuntime;
  final CartResourceRequests _cartRequests;

  /// Gets authenticated loyalty availability and rewards for a cart.
  Future<LoyaltyQuote> getQuote(
    String locationId,
    String cartId, {
    StorefrontRequestOptions? options,
  }) =>
      _cartRequests.send<LoyaltyQuote>(
        method: 'GET',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['loyalty', 'quote'],
        routeTemplate: '/locations/:locationId/carts/:cartId/loyalty/quote',
        authorization: StorefrontAuthorization.customer,
        persistRevision: true,
        decoder: (value) => LoyaltyQuote.fromJson(decodeJsonObject(value)),
        options: options,
      );

  /// Applies an authenticated customer's loyalty reward to a cart.
  Future<StorefrontCart> redeem(
    String locationId,
    String cartId,
    RedeemLoyaltyRequest request, {
    StorefrontRequestOptions? options,
  }) async {
    final rewardId = request.rewardId.trim();
    if (rewardId.isEmpty || rewardId.length > 128) {
      throw const StorefrontConfigurationException(
        'rewardId must contain 1 to 128 characters.',
      );
    }
    return _cartRequests.send<StorefrontCart>(
      method: 'POST',
      locationId: locationId,
      cartId: cartId,
      suffix: const ['loyalty', 'redeem'],
      routeTemplate: '/locations/:locationId/carts/:cartId/loyalty/redeem',
      authorization: StorefrontAuthorization.customer,
      body: <String, Object?>{'rewardId': rewardId},
      idempotent: true,
      revisionRequired: true,
      persistRevision: true,
      refreshOnConflict: true,
      revisionFallback: (cart) => cart.revision,
      validateResponse: (cart) => validateCartResponseIdentity(
        cart,
        locationId: locationId,
        cartId: cartId,
        method: 'POST',
        routeTemplate: '/locations/:locationId/carts/:cartId/loyalty/redeem',
      ),
      decoder: (value) => StorefrontCart.fromJson(decodeJsonObject(value)),
      options: options,
    );
  }

  /// Cancels an authenticated customer's applied loyalty redemption.
  Future<StorefrontCart> cancelRedemption(
    String locationId,
    String cartId, {
    StorefrontRequestOptions? options,
  }) =>
      _cartRequests.send<StorefrontCart>(
        method: 'DELETE',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['loyalty', 'redeem'],
        routeTemplate: '/locations/:locationId/carts/:cartId/loyalty/redeem',
        authorization: StorefrontAuthorization.customer,
        body: const <String, Object?>{},
        idempotent: true,
        revisionRequired: true,
        persistRevision: true,
        refreshOnConflict: true,
        revisionFallback: (cart) => cart.revision,
        validateResponse: (cart) => validateCartResponseIdentity(
          cart,
          locationId: locationId,
          cartId: cartId,
          method: 'DELETE',
          routeTemplate: '/locations/:locationId/carts/:cartId/loyalty/redeem',
        ),
        decoder: (value) => StorefrontCart.fromJson(decodeJsonObject(value)),
        options: options,
      );

  /// Gets one page of the authenticated customer's loyalty ledger.
  Future<LoyaltyLedger> getLedger({
    int limit = 25,
    String? cursor,
    StorefrontRequestOptions? options,
  }) async {
    if (limit < 1 || limit > 50) {
      throw const StorefrontConfigurationException(
        'Loyalty ledger limit must be between 1 and 50.',
      );
    }
    final normalizedCursor = cursor?.trim();
    if (cursor != null &&
        (normalizedCursor!.isEmpty || normalizedCursor.length > 512)) {
      throw const StorefrontConfigurationException(
        'Loyalty ledger cursor must contain 1 to 512 characters.',
      );
    }
    final response = await _transport.send<LoyaltyLedger>(
      method: 'GET',
      pathSegments: const ['customer', 'loyalty', 'ledger'],
      routeTemplate: '/customer/loyalty/ledger',
      authorization: StorefrontAuthorization.customer,
      query: {
        'limit': limit,
        if (normalizedCursor != null) 'cursor': normalizedCursor,
      },
      decoder: (value) => LoyaltyLedger.fromJson(decodeJsonObject(value)),
      timeout: options?.timeout,
      cancellationToken: options?.cancellationToken,
    );
    return response.data;
  }

  /// Submits a missing- or incorrect-points claim for a customer-owned order.
  Future<LoyaltyClaimSubmission> submitClaim(
    SubmitLoyaltyClaimRequest request, {
    StorefrontRequestOptions? options,
  }) async {
    if (!_loyaltyClaimOrderIdPattern.hasMatch(request.orderId)) {
      throw const StorefrontConfigurationException(
        'orderId must be a 24-character hexadecimal identifier.',
      );
    }
    final normalizedNote = request.note?.trim();
    if (request.note != null &&
        (normalizedNote!.isEmpty || normalizedNote.length > 1000)) {
      throw const StorefrontConfigurationException(
        'A loyalty claim note must contain 1 to 1000 characters.',
      );
    }
    final idempotencyKey =
        options?.idempotencyKey ?? _cartRuntime.idempotencyKeyGenerator.next();
    final response = await _transport.send<LoyaltyClaimSubmission>(
      method: 'POST',
      pathSegments: const ['customer', 'loyalty', 'claims'],
      routeTemplate: '/customer/loyalty/claims',
      authorization: StorefrontAuthorization.customer,
      idempotencyKey: idempotencyKey,
      body: <String, Object?>{
        'orderId': request.orderId,
        'reason': request.reason.wireValue,
        if (normalizedNote != null) 'note': normalizedNote,
      },
      decoder: (value) =>
          LoyaltyClaimSubmission.fromJson(decodeJsonObject(value)),
      timeout: options?.timeout,
      cancellationToken: options?.cancellationToken,
    );
    return response.data;
  }

  /// Lists the authenticated customer's submitted loyalty claims.
  Future<LoyaltyClaims> listClaims({
    StorefrontRequestOptions? options,
  }) async {
    final response = await _transport.send<LoyaltyClaims>(
      method: 'GET',
      pathSegments: const ['customer', 'loyalty', 'claims'],
      routeTemplate: '/customer/loyalty/claims',
      authorization: StorefrontAuthorization.customer,
      decoder: (value) => LoyaltyClaims.fromJson(decodeJsonObject(value)),
      timeout: options?.timeout,
      cancellationToken: options?.cancellationToken,
    );
    return response.data;
  }
}
