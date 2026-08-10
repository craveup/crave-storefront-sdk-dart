import '../errors.dart';
import '../http/transport.dart';
import '../models/cart.dart';
import '../runtime/cart_session_runtime.dart';
import '../runtime/request_runtime.dart';
import 'resource_support.dart';

/// Internal owner of cart-scoped authorization and concurrency behavior.
final class CartResourceRequests {
  const CartResourceRequests(this._transport, this._cartRuntime);

  final StorefrontTransport _transport;
  final CartSessionRuntime _cartRuntime;

  /// Sends a reviewed cart-scoped operation through the shared lifecycle.
  Future<T> send<T>({
    required String method,
    required String locationId,
    required String cartId,
    required List<String> suffix,
    required String routeTemplate,
    required T Function(Object? value) decoder,
    StorefrontAuthorization authorization = StorefrontAuthorization.cart,
    Object? body,
    bool idempotent = false,
    bool revisionRequired = false,
    bool persistRevision = false,
    bool refreshOnConflict = false,
    int? Function(T value)? revisionFallback,
    StorefrontRequestOptions? options,
  }) async {
    final context = await _cartRuntime.contextFor(
      locationId: locationId,
      cartId: cartId,
      idempotent: idempotent,
      revisionRequired: revisionRequired,
      options: options,
    );
    if (revisionRequired && context.revision == null) {
      throw const StorefrontConfigurationException(
        'A cart revision is required before mutation.',
      );
    }
    try {
      final response = await _transport.send<T>(
        method: method,
        pathSegments: ['locations', locationId, 'carts', cartId, ...suffix],
        routeTemplate: routeTemplate,
        authorization: authorization,
        cartToken: context.accessToken,
        idempotencyKey: context.idempotencyKey,
        revision: revisionRequired
            ? StorefrontRevision.cart(context.revision!)
            : null,
        body: body,
        decoder: decoder,
        timeout: options?.timeout,
        cancellationToken: options?.cancellationToken,
      );
      if (persistRevision) {
        await _cartRuntime.persistRevision(
          locationId: locationId,
          cartId: cartId,
          etag: response.etag,
          fallback: revisionFallback?.call(response.data),
        );
      }
      return response.data;
    } on StorefrontApiException catch (error) {
      if (refreshOnConflict && error.isCartConflict) {
        await _refreshAfterConflict(locationId, cartId, options);
      }
      rethrow;
    }
  }

  Future<void> _refreshAfterConflict(
    String locationId,
    String cartId,
    StorefrontRequestOptions? options,
  ) async {
    try {
      final context = await _cartRuntime.contextFor(
        locationId: locationId,
        cartId: cartId,
        idempotent: false,
        revisionRequired: false,
        options: options,
      );
      final response = await _transport.send<StorefrontCart>(
        method: 'GET',
        pathSegments: ['locations', locationId, 'carts', cartId],
        routeTemplate: '/locations/:locationId/carts/:cartId',
        authorization: StorefrontAuthorization.cart,
        cartToken: context.accessToken,
        decoder: (value) => StorefrontCart.fromJson(decodeJsonObject(value)),
        timeout: options?.timeout,
        cancellationToken: options?.cancellationToken,
      );
      await _cartRuntime.persistRevision(
        locationId: locationId,
        cartId: cartId,
        etag: response.etag,
        fallback: response.data.revision,
      );
    } on Object {
      // Keep the original conflict as the actionable reconciliation error.
    }
  }
}
