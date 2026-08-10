import 'dart:convert';

import '../errors.dart';
import '../http/transport.dart';
import '../models/analytics.dart';
import '../models/cart.dart';
import '../models/catalog.dart';
import '../models/ordering.dart';
import '../runtime/cart_session_runtime.dart';
import '../runtime/request_runtime.dart';
import 'cart_resource_support.dart';
import 'resource_support.dart';

/// Creates ordering-session resources for the package facade.
OrderingSessionsClient createOrderingSessionsClient(
  StorefrontTransport transport,
  CartSessionRuntime cartRuntime,
) =>
    OrderingSessionsClient._(transport, cartRuntime);

/// Creates analytics-event resources for the package facade.
AnalyticsEventsClient createAnalyticsEventsClient(
  StorefrontTransport transport,
  CartSessionRuntime cartRuntime,
) =>
    AnalyticsEventsClient._(transport, cartRuntime);

/// Creates cart resources for the package facade.
CartsClient createCartsClient(
  StorefrontTransport transport,
  CartSessionRuntime cartRuntime,
) =>
    CartsClient._(transport, cartRuntime);

/// Ordering-session bootstrap and resume operations.
final class OrderingSessionsClient {
  OrderingSessionsClient._(this._transport, this._cartRuntime);

  final StorefrontTransport _transport;
  final CartSessionRuntime _cartRuntime;
  final OrderingSessionCoordinator _coordinator = OrderingSessionCoordinator();

  /// Starts a new cart or resumes an available cart.
  Future<StartOrderingSessionResult> start(
    String locationId,
    StartOrderingSessionRequest request, {
    StorefrontRequestOptions? options,
  }) async {
    final payload = <String, Object?>{...request.toJson()};
    final key = jsonEncode([locationId, payload]);
    Future<StartOrderingSessionResult> operation() =>
        _performStart(locationId, payload, options);
    return options == null ? _coordinator.run(key, operation) : operation();
  }

  Future<StartOrderingSessionResult> _performStart(
    String locationId,
    Map<String, Object?> payload,
    StorefrontRequestOptions? options,
  ) async {
    const method = 'POST';
    const routeTemplate = '/locations/:locationId/ordering-sessions';
    final operation = StorefrontOperationContext(
      defaultTimeout: _transport.defaultTimeout,
      method: method,
      routeTemplate: routeTemplate,
      options: options,
    );
    if (!payload.containsKey('existingCartId')) {
      final stored = await operation.waitForSession(
        _cartRuntime.activeSessionFor(locationId),
        operationMayHaveSucceeded: false,
      );
      if (stored != null) {
        payload['existingCartId'] = stored.cartId;
      }
    }
    final existingCartId = payload['existingCartId'];
    Future<StartOrderingSessionResult> send() async {
      final context = existingCartId is String
          ? await operation.waitForSession(
              _cartRuntime.contextFor(
                locationId: locationId,
                cartId: existingCartId,
                idempotent: true,
                revisionRequired: true,
                options: options,
              ),
              operationMayHaveSucceeded: false,
            )
          : await operation.waitForSession(
              _cartRuntime.contextFor(
                locationId: locationId,
                cartId: '__new_cart__',
                idempotent: true,
                revisionRequired: false,
                options: options,
              ),
              operationMayHaveSucceeded: false,
            );
      if (existingCartId is String && context.revision == null) {
        throw const StorefrontConfigurationException(
          'A cart revision is required to resume an ordering session.',
        );
      }
      final response = await _transport.send<StartOrderingSessionResult>(
        method: method,
        pathSegments: ['locations', locationId, 'ordering-sessions'],
        routeTemplate: routeTemplate,
        authorization: existingCartId is String
            ? StorefrontAuthorization.cart
            : StorefrontAuthorization.optionalCustomer,
        cartToken: context.accessToken,
        idempotencyKey: context.idempotencyKey,
        revision: existingCartId is String && context.revision != null
            ? StorefrontRevision.cart(context.revision!)
            : null,
        body: payload,
        decoder: (value) =>
            StartOrderingSessionResult.fromJson(decodeJsonObject(value)),
        timeout: operation.remaining,
        cancellationToken: operation.cancellationToken,
      );
      final result = response.data;
      if (result.cart.locationId != locationId ||
          (existingCartId is String && result.cart.id != existingCartId)) {
        throw StorefrontDecodingException(
          method: method,
          routeTemplate: routeTemplate,
          retryIdempotencyKey: context.idempotencyKey,
        );
      }
      final etagRevision = parseCartRevision(response.etag);
      if (etagRevision == null || etagRevision != result.cart.revision) {
        throw StorefrontDecodingException(
          method: method,
          routeTemplate: routeTemplate,
          retryIdempotencyKey: context.idempotencyKey,
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
        retryIdempotencyKey: context.idempotencyKey,
      );
      return result;
    }

    return existingCartId is String
        ? _cartRuntime.serializeCartOperation(
            locationId: locationId,
            cartId: existingCartId,
            waitForPrevious: operation.wait,
            operation: send,
          )
        : send();
  }
}

/// Best-effort public Storefront analytics operations.
final class AnalyticsEventsClient {
  const AnalyticsEventsClient._(this._transport, this._cartRuntime);

  final StorefrontTransport _transport;
  final CartSessionRuntime _cartRuntime;

  /// Submits an allowlisted analytics event.
  Future<AnalyticsEventResult> submit(
    String locationId,
    AnalyticsEventRequest event, {
    StorefrontRequestOptions? options,
  }) async {
    const method = 'POST';
    const routeTemplate = '/locations/:locationId/analytics-events';
    final operation = StorefrontOperationContext(
      defaultTimeout: _transport.defaultTimeout,
      method: method,
      routeTemplate: routeTemplate,
      options: options,
    );
    final context = await operation.waitForSession(
      _cartRuntime.contextFor(
        locationId: locationId,
        cartId: event.cartId,
        idempotent: true,
        revisionRequired: false,
        options: options,
      ),
      operationMayHaveSucceeded: false,
    );
    final response = await _transport.send<AnalyticsEventResult>(
      method: method,
      pathSegments: ['locations', locationId, 'analytics-events'],
      routeTemplate: routeTemplate,
      authorization: StorefrontAuthorization.cart,
      cartToken: context.accessToken,
      idempotencyKey: context.idempotencyKey,
      body: event.toJson(),
      decoder: (value) =>
          AnalyticsEventResult.fromJson(decodeJsonObject(value)),
      timeout: operation.remaining,
      cancellationToken: operation.cancellationToken,
    );
    return response.data;
  }
}

/// Cart, item, discount, fulfillment, and claim operations.
final class CartsClient {
  CartsClient._(StorefrontTransport transport, this._cartRuntime)
      : _requests = CartResourceRequests(transport, _cartRuntime);

  final CartSessionRuntime _cartRuntime;
  final CartResourceRequests _requests;

  /// Gets a cart using its guest capability or owning customer JWT.
  Future<StorefrontCart> get(
    String locationId,
    String cartId, {
    StorefrontRequestOptions? options,
  }) =>
      _cart(
        method: 'GET',
        locationId: locationId,
        cartId: cartId,
        routeTemplate: '/locations/:locationId/carts/:cartId',
        options: options,
      );

  /// Lists compact product recommendations for a cart.
  Future<List<CartRecommendation>> listRecommendedProducts(
    String locationId,
    String cartId, {
    StorefrontRequestOptions? options,
  }) =>
      _requests.send<List<CartRecommendation>>(
        method: 'GET',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['products'],
        routeTemplate: '/locations/:locationId/carts/:cartId/products',
        persistRevision: true,
        decoder: (value) => List<CartRecommendation>.unmodifiable(
          decodeJsonObjectList(value).map(CartRecommendation.fromJson),
        ),
        options: options,
      );

  /// Updates allowlisted cart fulfillment or timing fields.
  Future<StorefrontCart> update(
    String locationId,
    String cartId,
    UpdateCartRequest request, {
    StorefrontRequestOptions? options,
  }) =>
      _cart(
        method: 'PATCH',
        locationId: locationId,
        cartId: cartId,
        routeTemplate: '/locations/:locationId/carts/:cartId',
        body: request.toJson(),
        mutation: true,
        options: options,
      );

  /// Deletes a cart and clears only its matching stored session.
  Future<StorefrontCart> delete(
    String locationId,
    String cartId, {
    StorefrontRequestOptions? options,
  }) =>
      _cart(
        method: 'DELETE',
        locationId: locationId,
        cartId: cartId,
        routeTemplate: '/locations/:locationId/carts/:cartId',
        body: const <String, Object?>{},
        mutation: true,
        allowExpiredSession: true,
        afterSuccess: () =>
            _cartRuntime.clear(locationId: locationId, cartId: cartId),
        options: options,
      );

  /// Validates customer contact details and updates the cart.
  Future<StorefrontCart> validateForCheckout(
    String locationId,
    String cartId,
    ValidateCartCustomerRequest request, {
    StorefrontRequestOptions? options,
  }) =>
      _cartMutation(
        method: 'PUT',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['validate-and-update'],
        routeSuffix: '/validate-and-update',
        body: request.toJson(),
        options: options,
      );

  /// Updates cart gratuity.
  Future<StorefrontCart> updateGratuity(
    String locationId,
    String cartId,
    UpdateGratuityRequest request, {
    StorefrontRequestOptions? options,
  }) =>
      _cartMutation(
        method: 'PUT',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['gratuity'],
        routeSuffix: '/gratuity',
        body: request.toJson(),
        options: options,
      );

  /// Sets delivery details on a cart.
  Future<StorefrontCart> setDelivery(
    String locationId,
    String cartId,
    SetDeliveryRequest request, {
    StorefrontRequestOptions? options,
  }) =>
      _cartMutation(
        method: 'PUT',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['set-delivery'],
        routeSuffix: '/set-delivery',
        body: request.toJson(),
        options: options,
      );

  /// Sets a table number on a cart.
  Future<StorefrontCart> setTable(
    String locationId,
    String cartId,
    SetTableRequest request, {
    StorefrontRequestOptions? options,
  }) =>
      _cartMutation(
        method: 'PUT',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['set-table'],
        routeSuffix: '/set-table',
        body: request.toJson(),
        options: options,
      );

  /// Sets room-service details on a cart.
  Future<StorefrontCart> setRoom(
    String locationId,
    String cartId,
    SetRoomRequest request, {
    StorefrontRequestOptions? options,
  }) =>
      _cartMutation(
        method: 'PUT',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['set-room'],
        routeSuffix: '/set-room',
        body: request.toJson(),
        options: options,
      );

  /// Updates ASAP or scheduled order timing.
  Future<StorefrontCart> updateOrderTime(
    String locationId,
    String cartId,
    UpdateOrderTimeRequest request, {
    StorefrontRequestOptions? options,
  }) =>
      _cartMutation(
        method: 'PUT',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['update-order-time'],
        routeSuffix: '/update-order-time',
        body: request.toJson(),
        options: options,
      );

  /// Applies a public discount code.
  Future<StorefrontCart> applyDiscount(
    String locationId,
    String cartId,
    ApplyDiscountRequest request, {
    StorefrontRequestOptions? options,
  }) =>
      _cartMutation(
        method: 'POST',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['discount'],
        routeSuffix: '/discount',
        body: request.toJson(),
        options: options,
      );

  /// Removes the applied public discount.
  Future<StorefrontCart> removeDiscount(
    String locationId,
    String cartId, {
    StorefrontRequestOptions? options,
  }) =>
      _cartMutation(
        method: 'DELETE',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['discount'],
        routeSuffix: '/discount',
        body: const <String, Object?>{},
        options: options,
      );

  /// Claims a guest cart for the signed-in customer.
  Future<StorefrontCart> claim(
    String locationId,
    String cartId, {
    StorefrontRequestOptions? options,
  }) async {
    return _cartMutation(
      method: 'POST',
      locationId: locationId,
      cartId: cartId,
      suffix: const ['claim'],
      routeSuffix: '/claim',
      body: const <String, Object?>{},
      authorization: StorefrontAuthorization.cartAndCustomer,
      afterSuccess: () => _cartRuntime.removeCapability(
        locationId: locationId,
        cartId: cartId,
      ),
      options: options,
    );
  }

  /// Adds a configured product to a cart.
  Future<StorefrontCart> addItem(
    String locationId,
    String cartId,
    AddCartItemRequest request, {
    StorefrontRequestOptions? options,
  }) =>
      _cartMutation(
        method: 'POST',
        locationId: locationId,
        cartId: cartId,
        suffix: const ['items'],
        routeSuffix: '/items',
        body: request.toJson(),
        options: options,
      );

  /// Updates one cart-item quantity.
  Future<StorefrontCart> updateItemQuantity(
    String locationId,
    String cartId,
    String itemId,
    UpdateCartItemQuantityRequest request, {
    StorefrontRequestOptions? options,
  }) =>
      _cartMutation(
        method: 'PATCH',
        locationId: locationId,
        cartId: cartId,
        suffix: ['items', itemId],
        routeSuffix: '/items/:itemId',
        body: request.toJson(),
        options: options,
      );

  /// Removes one item from a cart.
  Future<StorefrontCart> removeItem(
    String locationId,
    String cartId,
    String itemId, {
    StorefrontRequestOptions? options,
  }) =>
      _cartMutation(
        method: 'DELETE',
        locationId: locationId,
        cartId: cartId,
        suffix: ['items', itemId],
        routeSuffix: '/items/:itemId',
        options: options,
      );

  Future<StorefrontCart> _cartMutation({
    required String method,
    required String locationId,
    required String cartId,
    required List<String> suffix,
    required String routeSuffix,
    Object? body,
    StorefrontAuthorization authorization = StorefrontAuthorization.cart,
    Future<void> Function()? afterSuccess,
    StorefrontRequestOptions? options,
  }) =>
      _cart(
        method: method,
        locationId: locationId,
        cartId: cartId,
        suffix: suffix,
        routeTemplate: '/locations/:locationId/carts/:cartId$routeSuffix',
        body: body,
        authorization: authorization,
        mutation: true,
        afterSuccess: afterSuccess,
        options: options,
      );

  Future<StorefrontCart> _cart({
    required String method,
    required String locationId,
    required String cartId,
    required String routeTemplate,
    List<String> suffix = const [],
    Object? body,
    StorefrontAuthorization authorization = StorefrontAuthorization.cart,
    bool mutation = false,
    bool allowExpiredSession = false,
    Future<void> Function()? afterSuccess,
    StorefrontRequestOptions? options,
  }) =>
      _requests.send<StorefrontCart>(
        method: method,
        locationId: locationId,
        cartId: cartId,
        suffix: suffix,
        routeTemplate: routeTemplate,
        authorization: authorization,
        body: body,
        idempotent: mutation,
        revisionRequired: mutation,
        persistRevision: true,
        refreshOnConflict: mutation,
        allowExpiredSession: allowExpiredSession,
        validateResponse: (cart) => validateCartResponseIdentity(
          cart,
          locationId: locationId,
          cartId: cartId,
          method: method,
          routeTemplate: routeTemplate,
        ),
        afterSuccess: afterSuccess,
        revisionFallback: (cart) => cart.revision,
        decoder: (value) => StorefrontCart.fromJson(decodeJsonObject(value)),
        options: options,
      );
}
