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

/// Ordering-session bootstrap and resume operations.
final class OrderingSessionsClient {
  OrderingSessionsClient(this._transport, this._cartRuntime);

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
    if (!payload.containsKey('existingCartId')) {
      final stored = await _cartRuntime.sessionStore.read(
        _cartRuntime.scopeFor(locationId),
      );
      if (stored != null) {
        payload['existingCartId'] = stored.cartId;
      }
    }
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
    final existingCartId = payload['existingCartId'];
    final context = existingCartId is String
        ? await _cartRuntime.contextFor(
            locationId: locationId,
            cartId: existingCartId,
            idempotent: true,
            revisionRequired: true,
            options: options,
          )
        : await _cartRuntime.contextFor(
            locationId: locationId,
            cartId: '__new_cart__',
            idempotent: true,
            revisionRequired: false,
            options: options,
          );
    if (existingCartId is String && context.revision == null) {
      throw const StorefrontConfigurationException(
        'A cart revision is required to resume an ordering session.',
      );
    }
    final response = await _transport.send<StartOrderingSessionResult>(
      method: 'POST',
      pathSegments: ['locations', locationId, 'ordering-sessions'],
      routeTemplate: '/locations/:locationId/ordering-sessions',
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
      timeout: options?.timeout,
      cancellationToken: options?.cancellationToken,
    );
    final result = response.data;
    await _cartRuntime.capture(
      locationId: locationId,
      cartId: result.cart.id,
      accessToken: result.cartAccessToken,
      revision: parseCartRevision(response.etag) ?? result.cart.revision,
      expiresAt: result.cart.expiresAt == null
          ? null
          : DateTime.tryParse(result.cart.expiresAt!),
    );
    return result;
  }
}

/// Best-effort public Storefront analytics operations.
final class AnalyticsEventsClient {
  const AnalyticsEventsClient(this._transport, this._cartRuntime);

  final StorefrontTransport _transport;
  final CartSessionRuntime _cartRuntime;

  /// Submits an allowlisted analytics event.
  Future<AnalyticsEventResult> submit(
    String locationId,
    AnalyticsEventRequest event, {
    StorefrontRequestOptions? options,
  }) async {
    final context = await _cartRuntime.contextFor(
      locationId: locationId,
      cartId: event.cartId,
      idempotent: true,
      revisionRequired: false,
      options: options,
    );
    final response = await _transport.send<AnalyticsEventResult>(
      method: 'POST',
      pathSegments: ['locations', locationId, 'analytics-events'],
      routeTemplate: '/locations/:locationId/analytics-events',
      authorization: StorefrontAuthorization.cart,
      cartToken: context.accessToken,
      idempotencyKey: context.idempotencyKey,
      body: event.toJson(),
      decoder: (value) =>
          AnalyticsEventResult.fromJson(decodeJsonObject(value)),
      timeout: options?.timeout,
      cancellationToken: options?.cancellationToken,
    );
    return response.data;
  }
}

/// Cart, item, discount, fulfillment, and claim operations.
final class CartsClient {
  CartsClient(StorefrontTransport transport, this._cartRuntime)
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
        decoder: (value) => decodeJsonObjectList(value)
            .map(CartRecommendation.fromJson)
            .toList(growable: false),
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
  }) async {
    final cart = await _cart(
      method: 'DELETE',
      locationId: locationId,
      cartId: cartId,
      routeTemplate: '/locations/:locationId/carts/:cartId',
      body: const <String, Object?>{},
      mutation: true,
      options: options,
    );
    await _cartRuntime.clear(locationId: locationId, cartId: cartId);
    return cart;
  }

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
    final cart = await _cartMutation(
      method: 'POST',
      locationId: locationId,
      cartId: cartId,
      suffix: const ['claim'],
      routeSuffix: '/claim',
      body: const <String, Object?>{},
      authorization: StorefrontAuthorization.cartAndCustomer,
      options: options,
    );
    await _cartRuntime.removeCapability(
      locationId: locationId,
      cartId: cartId,
    );
    return cart;
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
        revisionFallback: (cart) => cart.revision,
        decoder: (value) => StorefrontCart.fromJson(decodeJsonObject(value)),
        options: options,
      );
}
