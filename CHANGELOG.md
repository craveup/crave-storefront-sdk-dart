# Changelog

All notable changes to this package are documented here. This project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

- Add the typed `CraveStorefrontClient` and Storefront resource clients.
- Add customer identity, cart capability, checkout handoff, receipt, revision, and idempotency
  lifecycle handling.
- Add caller-owned asynchronous session storage and an in-memory test implementation.
- Serialize complete same-cart lifecycles so delayed responses cannot reverse session cleanup.
- Add typed, redaction-safe configuration, network, timeout, cancellation, decoding, session, and
  server failures, including recoverable idempotency keys for ambiguous mutation outcomes.
- Add Dart and Flutter consumer verification plus release-ready pub.dev metadata.

This is the first public preview. There are no migration steps from an earlier Dart release.
