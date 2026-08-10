# Crave Storefront SDK for Dart

[![CI](https://github.com/craveup/crave-storefront-sdk-dart/actions/workflows/ci.yml/badge.svg)](https://github.com/craveup/crave-storefront-sdk-dart/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/crave_storefront_sdk.svg)](https://pub.dev/packages/crave_storefront_sdk)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A lightweight, type-safe Dart client for building Crave-powered Flutter storefronts. The SDK keeps
tenant configuration, authorization, cart capabilities, revisions, idempotency, cancellation, and
safe failure decoding behind one reviewed client surface. It has no Flutter or native runtime
dependency.

> `0.1.x` is a preview of the public contract. Pin a compatible version and review the
> [changelog](CHANGELOG.md) before upgrading.

## Requirements

- Dart 3.4 or newer
- A Crave Storefront API origin
- Your canonical merchant slug

## Install

Add the released preview to your application:

```yaml
dependencies:
  crave_storefront_sdk: 0.1.0
```

Then run `flutter pub get` (or `dart pub get` for a Dart package).

## Quick start

Configure the API origin and merchant explicitly. Pass a caller-owned session store backed by
encrypted platform storage, plus a customer JWT provider that reads the signed-in user's current
token only when the SDK needs it.

```dart
import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';

CraveStorefrontClient createStorefrontClient({
  required StorefrontSessionStore secureSessionStore,
  required StorefrontCustomerTokenProvider currentCustomerJwt,
}) {
  return CraveStorefrontClient(
    baseUri: Uri.parse('https://api.example.com'),
    merchantSlug: 'example-merchant',
    sessionStore: secureSessionStore,
    customerTokenProvider: currentCustomerJwt,
  );
}

typedef OrderingBootstrap = ({
  MenuBundle menu,
  StartOrderingSessionResult orderingSession,
});

Future<OrderingBootstrap> browseAndStartTakeout(
  CraveStorefrontClient client,
  String locationId,
) async {
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
```

Close the client when its application-level owner is disposed:

```dart
client.close();
```

The SDK closes only the network client it creates. Only use an injected `http.Client` that your
application trusts and audits: an injected client can observe resolved URLs, authorization and
capability headers, and request/response bodies. The SDK cannot control logging, proxying, or other
behavior implemented inside that client, and your application remains responsible for closing it.

## Resources

`CraveStorefrontClient` exposes focused, typed resource clients:

| Property | Responsibility |
| --- | --- |
| `merchants`, `locations` | Merchant identity, location discovery, and distance |
| `menus`, `products` | Catalog, categories, products, and modifier choices |
| `orderingSessions`, `carts` | Ordering bootstrap and cart lifecycle |
| `customers` | Identity, orders, addresses, and saved payment references |
| `checkout`, `receipts`, `ratings` | Checkout handoff, receipt access, and feedback |
| `analyticsEvents` | Storefront event submission |
| `loyalty` | Quote, redemption, ledger, and claim flows |

Only reviewed Storefront operations are available. Request routes and protected headers are owned
by the SDK so application code cannot accidentally send credentials or capabilities to an
unrelated origin.

## Session storage and identity

`StorefrontSessionStore` is asynchronous and caller-owned. Scope every record by the API origin,
merchant slug, and location ID supplied through `StorefrontSessionScope`. In a production Flutter
app, adapt it to encrypted platform storage. `InMemoryStorefrontSessionStore` is intended only for
tests and ephemeral demos.

The stored cart session may contain the cart ID, cart capability, and latest revision. Never persist
customer JWTs, checkout handoffs, receipt capabilities, one-time codes, or payment secrets in the
SDK session record. Clear your application's signed-in token source on logout; the customer JWT
provider can then return `null` for anonymous operations.

The client serializes each cart's complete request and session-update lifecycle. This prevents a
delayed response from restoring state after deletion, claim, rating cleanup, ordering resume, or
handoff exchange. Different carts remain independent, and a queued operation that reaches its
deadline or is cancelled is removed without issuing a late HTTP request.

## Cancellation and timeouts

Each operation that accepts `StorefrontRequestOptions` can use a per-call timeout and a
`StorefrontCancellationToken`:

```dart
final cancellation = StorefrontCancellationToken();
final options = StorefrontRequestOptions(
  timeout: const Duration(seconds: 12),
  cancellationToken: cancellation,
);

// Pass options to the typed resource operation. A UI owner can later call:
cancellation.cancel();
```

Cancellation throws `StorefrontRequestCancelledException`; a deadline throws
`StorefrontTimeoutException`. Neither is retried automatically. Create each cancellation token for
one logical operation and discard it when that operation settles, even if it was never cancelled;
cancellation listeners remain tied to that token. Do not reuse a completed token or keep any token
as a long-lived application singleton.

## Typed failures and conflicts

Server failures throw `StorefrontApiException` with a safe code, message, status, request ID,
method, and route template. Network, decoding, configuration, timeout, cancellation, and
caller-owned session failures have their own `StorefrontException` subtypes. Error text excludes
resolved URLs, request bodies, headers, customer data, payment values, and replay keys.

Cart mutations use the stored revision. If the server returns `CART_CONFLICT`, the SDK may refresh
the stored revision with one safe read, but it still throws the original conflict. Re-read the cart,
reconcile the user's intended change, then submit a new mutation. Mutations are never repeated
implicitly.

A timeout, cancellation, network failure, 408/5xx response, malformed success response, or
post-response session-store failure can have an ambiguous outcome: the server might have committed
a mutation before recovery information reached the app. These typed errors expose
`retryIdempotencyKey` when the interrupted request was idempotent; that value is deliberately absent
from `toString()`. Reconcile the current server state first. If the application deliberately replays
the exact same logical request, reuse the same idempotency key. A new logical mutation must use a new
key, and one key must never identify different payloads.

Create and retain the options before the first attempt when the application owns a recoverable
mutation workflow:

```dart
final mutationOptions = StorefrontRequestOptions(
  idempotencyKey: client.idempotencyKeyGenerator.next(),
);

try {
  await client.carts.update(
    locationId,
    cartId,
    const UpdateCartRequest(
      fulfillmentMethod: FulfillmentMethod.delivery,
    ),
    options: mutationOptions,
  );
} on StorefrontTimeoutException catch (error) {
  // Reconcile first. Reuse error.retryIdempotencyKey only for this exact
  // logical mutation; never reuse it for a changed payload.
}
```

```dart
try {
  // Await a typed cart mutation.
} on StorefrontApiException catch (error) {
  if (error.code == 'CART_CONFLICT') {
    // Re-read, reconcile, and let the user confirm the next mutation.
  }
}
```

## Security model

- Use HTTPS for deployed environments. Plain HTTP is accepted only on loopback hosts for local
  development.
- Obtain the customer JWT from your authentication layer through the callback. Do not put it in
  source, logs, crash metadata, analytics, or persistent SDK session state.
- Let the SDK own cart, checkout, receipt, idempotency, and revision headers.
- Treat checkout and receipt capabilities as call-scoped sensitive values.
- Treat an injected `http.Client` as trusted, privileged application code because it can observe
  sensitive headers and bodies.
- The SDK does not log requests or responses.

See [SECURITY.md](SECURITY.md) for private vulnerability reporting.

## Package scope

This package provides the Storefront API client and lifecycle behavior. UI components, state
management, authentication UI, encrypted-storage selection, payment confirmation UI, and a complete
Flutter storefront application belong in the consuming app. A small compile fixture lives under
`tool/flutter_consumer`; it is not an application template.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the test-first workflow and release gates. Public API
changes are durable, so open an issue before introducing or renaming one.

## License

[MIT](LICENSE)
