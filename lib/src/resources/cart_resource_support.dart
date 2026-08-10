import '../errors.dart';
import '../http/transport.dart';
import '../models/cart.dart';
import '../runtime/cart_session_runtime.dart';
import '../runtime/request_runtime.dart';
import 'resource_support.dart';

/// Rejects a cart response outside the exact requested resource scope.
void validateCartResponseIdentity(
  StorefrontCart cart, {
  required String locationId,
  required String cartId,
  required String method,
  required String routeTemplate,
}) {
  if (cart.id != cartId || cart.locationId != locationId) {
    throw StorefrontDecodingException(
      method: method,
      routeTemplate: routeTemplate,
    );
  }
}

/// Internal owner of cart-scoped authorization and concurrency behavior.
final class CartResourceRequests {
  /// Creates a shared cart request helper.
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
    bool allowExpiredSession = false,
    int? Function(T value)? revisionFallback,
    void Function(T value)? validateResponse,
    Future<void> Function()? afterSuccess,
    StorefrontRequestOptions? options,
  }) async {
    final operation = StorefrontOperationContext(
      defaultTimeout: _transport.defaultTimeout,
      method: method,
      routeTemplate: routeTemplate,
      options: options,
    );
    return _cartRuntime.serializeCartOperation<T>(
      locationId: locationId,
      cartId: cartId,
      waitForPrevious: operation.wait,
      operation: () async {
        final context = await operation.waitForSession(
          _cartRuntime.contextFor(
            locationId: locationId,
            cartId: cartId,
            idempotent: idempotent,
            revisionRequired: revisionRequired,
            options: options,
            allowExpiredSession: allowExpiredSession,
          ),
          operationMayHaveSucceeded: false,
        );
        if (revisionRequired && context.revision == null) {
          throw const StorefrontConfigurationException(
            'A cart revision is required before mutation.',
          );
        }
        try {
          final response = await _transport.send<T>(
            method: method,
            pathSegments: [
              'locations',
              locationId,
              'carts',
              cartId,
              ...suffix,
            ],
            routeTemplate: routeTemplate,
            authorization: authorization,
            cartToken: context.accessToken,
            idempotencyKey: context.idempotencyKey,
            revision: revisionRequired
                ? StorefrontRevision.cart(context.revision!)
                : null,
            body: body,
            decoder: decoder,
            timeout: operation.remaining,
            cancellationToken: operation.cancellationToken,
          );
          validateResponse?.call(response.data);
          final fallback = revisionFallback?.call(response.data);
          final etagRevision = parseCartRevision(response.etag);
          if (persistRevision && etagRevision == null) {
            throw StorefrontDecodingException(
              method: method,
              routeTemplate: routeTemplate,
              retryIdempotencyKey: context.idempotencyKey,
            );
          }
          if (etagRevision != null &&
              fallback != null &&
              etagRevision != fallback) {
            throw StorefrontDecodingException(
              method: method,
              routeTemplate: routeTemplate,
              retryIdempotencyKey: context.idempotencyKey,
            );
          }
          if (persistRevision) {
            await operation.waitForSession(
              _cartRuntime.persistRevision(
                locationId: locationId,
                cartId: cartId,
                etag: response.etag,
                fallback: fallback,
              ),
              operationMayHaveSucceeded: true,
              retryIdempotencyKey: context.idempotencyKey,
            );
          }
          if (afterSuccess != null) {
            await operation.waitForSession(
              afterSuccess(),
              operationMayHaveSucceeded: true,
              retryIdempotencyKey: context.idempotencyKey,
            );
          }
          return response.data;
        } on StorefrontApiException catch (error) {
          if (refreshOnConflict && error.isCartConflict) {
            await _refreshAfterConflict(
              locationId,
              cartId,
              operation,
              options,
            );
          }
          rethrow;
        } on StorefrontDecodingException catch (error) {
          if (error.retryIdempotencyKey != null ||
              context.idempotencyKey == null) {
            rethrow;
          }
          throw StorefrontDecodingException(
            method: error.method,
            routeTemplate: error.routeTemplate,
            retryIdempotencyKey: context.idempotencyKey,
          );
        }
      },
    );
  }

  Future<void> _refreshAfterConflict(
    String locationId,
    String cartId,
    StorefrontOperationContext operation,
    StorefrontRequestOptions? options,
  ) async {
    try {
      final context = await operation.waitForSession(
        _cartRuntime.contextFor(
          locationId: locationId,
          cartId: cartId,
          idempotent: false,
          revisionRequired: false,
          options: options,
        ),
        operationMayHaveSucceeded: true,
      );
      final response = await _transport.send<StorefrontCart>(
        method: 'GET',
        pathSegments: ['locations', locationId, 'carts', cartId],
        routeTemplate: '/locations/:locationId/carts/:cartId',
        authorization: StorefrontAuthorization.cart,
        cartToken: context.accessToken,
        decoder: (value) => StorefrontCart.fromJson(decodeJsonObject(value)),
        timeout: operation.remaining,
        cancellationToken: operation.cancellationToken,
      );
      if (response.data.id != cartId ||
          response.data.locationId != locationId) {
        throw const StorefrontDecodingException(
          method: 'GET',
          routeTemplate: '/locations/:locationId/carts/:cartId',
        );
      }
      final etagRevision = parseCartRevision(response.etag);
      if (etagRevision == null || etagRevision != response.data.revision) {
        throw const StorefrontDecodingException(
          method: 'GET',
          routeTemplate: '/locations/:locationId/carts/:cartId',
        );
      }
      await operation.waitForSession(
        _cartRuntime.persistRevision(
          locationId: locationId,
          cartId: cartId,
          etag: response.etag,
          fallback: response.data.revision,
        ),
        operationMayHaveSucceeded: true,
      );
    } on Object {
      // Keep the original conflict as the actionable reconciliation error.
    }
  }
}
