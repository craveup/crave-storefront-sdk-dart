import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';

/// Creates a minimal client from dependencies owned by the Flutter application.
CraveStorefrontClient createStorefrontClient({
  required StorefrontSessionStore secureSessionStore,
  required StorefrontCustomerTokenProvider customerJwtProvider,
}) {
  return CraveStorefrontClient(
    baseUri: Uri.parse('https://api.craveup.com'),
    merchantSlug: 'example-merchant',
    sessionStore: secureSessionStore,
    customerTokenProvider: customerJwtProvider,
  );
}

/// Typed results needed to render the catalog and the active cart.
typedef OrderingBootstrap = ({
  MenuBundle menu,
  StartOrderingSessionResult orderingSession,
});

/// Loads a typed menu and starts a fresh takeout ordering session.
Future<OrderingBootstrap> browseAndStartTakeout(
  CraveStorefrontClient client,
  String locationId,
) async {
  final readiness = await client.locations.getOrderingReadiness(
    locationId,
    fulfillmentMethod: FulfillmentMethod.takeout,
  );
  if (readiness case OrderingUnavailable(:final reason)) {
    throw StateError(reason);
  }
  final menu = await client.menus.getForLocation(locationId, menuOnly: true);
  final orderingSession = await client.orderingSessions.start(
    locationId,
    StartOrderingSessionRequest.fresh(
      fulfillmentMethod: 'takeout',
      channel: OrderChannel.app,
    ),
  );
  return (menu: menu, orderingSession: orderingSession);
}

/// Creates controls for one logical operation that a UI owner can cancel.
///
/// Use a fresh token for each operation and discard it after the operation settles.
StorefrontRequestOptions cancellableRequest(
  StorefrontCancellationToken cancellationToken,
) {
  return StorefrontRequestOptions(
    timeout: const Duration(seconds: 12),
    cancellationToken: cancellationToken,
  );
}

/// Creates options the caller retains for one replayable logical mutation.
StorefrontRequestOptions beginReplayableMutation(
  CraveStorefrontClient client,
) =>
    StorefrontRequestOptions(
      idempotencyKey: client.idempotencyKeyGenerator.next(),
    );

/// Whether a typed failure requires the application to reconcile its cart.
bool requiresCartReconciliation(StorefrontException error) =>
    error is StorefrontApiException && error.isCartConflict;

void main() {
  // The application passes its encrypted StorefrontSessionStore adapter and
  // current-customer token callback to createStorefrontClient, then owns the
  // returned client's lifecycle. Only inject a trusted, audited http.Client;
  // injected clients can observe request URLs, sensitive headers, and bodies.
}
