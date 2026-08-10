# Repository Guidelines

This repository is the canonical public source for the `crave_storefront_sdk` Dart package.

## Scope and architecture

- Keep the package pure Dart. Do not add native platform code or a Flutter SDK dependency unless a
  real platform capability requires it.
- Keep one public entrypoint at `lib/crave_storefront_sdk.dart`; implementation belongs in `lib/src`.
- Keep transport, authorization, session, revision, and idempotency behavior centralized. Resource
  clients must delegate to those owners rather than copying request logic.
- Do not expose a raw arbitrary-path HTTP client. Public methods must map to reviewed Storefront API
  operations.
- Never accept, persist, forward, or document merchant/admin API keys. Customer JWTs come from a
  callback; cart, checkout-handoff, and receipt capabilities use only their dedicated headers.
- Treat every published API as durable. Before the first release, replace greenfield code in place
  and remove obsolete paths rather than retaining aliases or compatibility shims.

## Quality

- Use test-driven development for behavior changes: observe a relevant failing test before adding
  implementation.
- Run `dart format --output=none --set-exit-if-changed .`, `dart analyze --fatal-infos`, and
  `dart test` before every commit.
- Before a release, also run `dart doc`, `dart pub publish --dry-run`, `pana`, the Flutter consumer
  fixture, dependency/advisory review, and a secret scan.
- Document all public APIs. Keep examples free of real merchant identifiers, tokens, customer data,
  and payment secrets.
- Use small, imperative commits and normal pull-request merges. Never publish from a dirty tree or a
  commit other than the reviewed release tag.
