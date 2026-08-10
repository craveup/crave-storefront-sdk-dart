# Crave Flutter Storefront SDK Design

**Date:** 2026-08-10
**Package:** `crave_storefront_sdk`
**Canonical source:** `https://github.com/craveup/crave-storefront-sdk-dart`
**Initial release:** `0.1.0` preview

## Goal

Provide external Flutter developers with a small, typed, secure client for the direct public Crave
Storefront API. The package covers discovery, catalog, ordering sessions, carts, customer identity,
checkout, receipts, ratings, and loyalty without embedding a private credential, UI framework, or
native plugin.

The first release is intentionally `0.1.0`: the API namespace is live, but Crave's executable
OpenAPI source and public sandbox qualification are still being completed. The implementation and
tests must nevertheless meet production library standards; the preview label describes contract
maturity, not relaxed code quality.

## Evidence and constraints

- The reviewed platform baseline is `craveup/craveup-turborepo` `origin/dev` at
  `7fb18e9918f2181d426a73762cd97f3deb7d5418`.
- The Express application mounts 50 operations below `/api/v1/storefront`: 49 JSON operations for
  typed SDK methods and one browser-only location redirect recorded as an explicit exclusion.
- The current hand-maintained Swagger registers only 15 path modules and has known stale response
  shapes. It cannot safely generate the public Dart API.
- The current TypeScript client is useful behavior evidence, but its handwritten DTOs also drift
  from runtime responses. It is not copied mechanically.
- The production namespace responds with the structured `{code,message,requestId,details}` error
  envelope and requires no API key. Qualification still needs an approved non-production
  merchant/location before stable `1.0.0`.
- `crave_storefront_sdk` is unclaimed on pub.dev as of this design. Publication is permanent and the
  first version requires interactive pub.dev authentication.

## Options considered

### 1. Curated pure-Dart SDK with a shared runtime — selected

Write an idiomatic facade and immutable DTOs around one internal transport/session core. Maintain a
machine-readable operation manifest and conformance tests. Generate DTOs later from the canonical
contract once it is complete.

This gives Flutter developers strong names and types while keeping the package small and the
security-sensitive lifecycle understandable.

### 2. Generate the whole SDK from current Swagger — rejected

Generation would be fast, but it would faithfully publish an incomplete and stale contract, expose
an awkward generic transport surface, and create large diffs without fixing lifecycle behavior.

### 3. Build a Flutter plugin wrapper — rejected

The Storefront API is HTTPS/JSON and needs no native capability. A plugin would add platform
registrants, Flutter coupling, and release complexity without user value.

## Package boundaries

The package is pure Dart and supports Flutter on Android, iOS, web, macOS, Windows, and Linux. It
targets Dart `>=3.4.0 <4.0.0` and depends only on the Dart team's `http` package at runtime.

Public consumers import only:

```dart
import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';
```

`CraveStorefrontClient` owns typed resource clients:

- `merchants`, `locations`, `menus`, and `products`;
- `orderingSessions`, `analyticsEvents`, and `carts`;
- `customers`, including orders, addresses, and saved payments;
- `checkout`, `receipts`, and `ratings`;
- `loyalty`, including quote, redemption, ledger, and claims.

There is no public raw request method and no arbitrary path input. Stripe confirmation, secure
storage implementation, UI components, state management, analytics vendors, and a full storefront
example application remain outside the package.

## Configuration and ownership

Construction requires:

- an explicit absolute `baseUri`;
- a canonical merchant slug for session isolation;
- an optional caller-owned `http.Client`;
- an optional async customer JWT provider;
- an optional caller-owned `StorefrontSessionStore`;
- bounded default timeout and injectable idempotency-key generator.

Production origins must use HTTPS. Plain HTTP is accepted only for loopback development. The SDK
normalizes to the origin, rejects credentials/fragments/query strings in the base URI, never infers
an environment, and never reads process or Flutter environment variables.

The SDK closes only an HTTP client it created. Injected clients remain caller-owned.

## Transport and security

All requests pass through one internal transport.

- Paths are fixed reviewed templates beneath `/api/v1/storefront` and segments are URI-encoded.
- Redirect following is disabled, so authorization and capability headers cannot cross origins.
- Caller headers are allowlisted. `Authorization`, `X-Cart-Token`, `X-Checkout-Handoff`,
  `X-Receipt-Token`, `Idempotency-Key`, `If-Match`, `X-API-Key`, host, and content-length are managed
  only by the SDK.
- Anonymous merchant, location, menu, product, ordering bootstrap, login, OTP, and handoff exchange
  calls never request a customer JWT.
- Customer routes use only the JWT provider. Cart routes use the matching cart capability and may
  use a customer JWT only where the server contract permits ownership.
- Ordering-session creation is public but may attach an available customer JWT to establish or
  resume customer ownership. Public catalog, login, OTP, and handoff-exchange calls never request a
  JWT.
- Checkout and receipt capabilities are call-scoped and sent only in their named headers.
- Every mutation that the API marks idempotent receives a 16–128 character safe key. A caller may
  supply a stable key; otherwise the SDK creates a cryptographically random key once per call.
- Cart mutations send `If-Match: "cart-N"`. Address updates send `If-Match: "address-N"`.
- Operations declared to return a resource ETag require a parseable header and verify it against
  the typed response revision before persisting state.
- Mutations are never retried implicitly. On `CART_CONFLICT`, the SDK may refresh the stored revision
  with one safe GET, but it rethrows the original conflict for caller reconciliation.
- `http.AbortableRequest` combines caller cancellation and timeout. Timeout and cancellation have
  distinct typed errors.

The SDK never logs. Errors expose status, safe error code/message, request ID, method, and route
template, but never the resolved URL, query, body, headers, tokens, OTPs, customer PII, or payment
client secret.

## Session lifecycle

`StorefrontSessionStore` is an async interface implemented by the application. The SDK ships an
explicitly documented in-memory implementation for tests and ephemeral demos; Flutter production
apps should adapt encrypted platform storage.

Every session is scoped by canonical API origin, merchant slug, and location ID. A stored value may
contain only cart ID, cart capability, revision, and optional merchant slug needed after checkout
handoff. Customer JWTs and receipt/handoff capabilities are never stored by the SDK.

Ordering-session creation captures a newly returned cart capability and revision. Concurrent
identical starts share one in-flight request and one idempotency key. Cart updates persist newer
ETag revisions. Deletion clears the session. Successful guest-cart claim removes the capability but
retains cart/revision for customer-JWT continuation. Failed operations do not discard recovery data.
The full request and storage lifecycle is serialized per scoped cart—including resume and handoff
exchange—so an older response cannot restore state after a later cleanup. Different carts remain
independent, and an operation that expires while queued never sends a late request.

## Models and decoding

Models are immutable, null-safe Dart types. One internal JSON reader provides contextual type errors
and removes repeated casts. Request DTOs serialize only allowlisted server fields; they cannot carry
prices, totals, merchant ownership, customer IDs, Stripe IDs, loyalty-member IDs, or status.

Response enums that the server can extend preserve unknown wire values rather than crashing.
Money remains decimal strings; restaurant-local dates and times remain wire strings; timestamps are
validated ISO-8601 strings unless a specific API contract defines a stronger type.

The checked-in operation manifest records method, route template, auth mode, idempotency, revision,
request model, and response model for all 50 routes. The browser redirect has no SDK method and an
exclusion reason; the other 49 entries map one-to-one to typed methods. The manifest is package test
data, not a second server contract. Once the core executable contract is complete, generation
replaces the manual descriptor and DTO boilerplate in one change; hand-written transport/session
behavior remains.

## Errors

The sealed public hierarchy is:

- `StorefrontApiException` for non-2xx server envelopes;
- `StorefrontTimeoutException`;
- `StorefrontRequestCancelledException`;
- `StorefrontNetworkException` with a safe cause category, not the raw URL-bearing exception;
- `StorefrontSessionException` for redacted caller-owned storage failures;
- `StorefrontDecodingException` for an invalid success payload;
- `StorefrontConfigurationException` for invalid local inputs.

Ambiguous idempotent failures expose a caller-recoverable `retryIdempotencyKey` that is excluded from
`toString()`. Error strings are redaction-safe and covered by hostile-value tests.

## Verification

Required before the first tag:

1. format, fatal-info analysis, complete unit tests, and generated API docs;
2. exact 50-operation route/auth/idempotency/revision manifest parity and 49 typed JSON methods;
3. hostile URL/header, redirect, cancellation, timeout, invalid JSON, and redaction tests;
4. cart capability, ETag conflict refresh, claim, deletion, merchant/origin isolation, same-cart
   lifecycle ordering, queued expiry, and concurrent ordering-session tests;
5. request/response fixture tests from sanitized runtime route examples;
6. minimum Dart 3.4 and current stable CI;
7. a clean Flutter consumer compile/test on current stable;
8. `dart pub publish --dry-run`, `pana`, documentation coverage, dependency/advisory review, package
   inventory review, and secret scan;
9. independent code/security/release review followed by a fix/review loop;
10. exact reviewed commit, normal PR merge, release tag, first manual pub.dev publication, and
    downloaded-artifact verification.

## Release and trust

The repository and package use MIT, matching Crave's public SDK/tooling convention. `main` is the
release branch. CI uses pinned actions. Future automated publication uses pub.dev OIDC only after the
first manual release and package transfer to a verified `craveup.com` publisher.

The pub.dev GitHub environment requires an approved reviewer. Release tags are protected. The
workflow receives only `contents: read` and `id-token: write`. No long-lived pub token is stored.

Stable `1.0.0` is gated on the canonical OpenAPI/operation coverage source, an approved public
sandbox fixture, cross-SDK conformance, and at least one clean Flutter storefront consumer.
