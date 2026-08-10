# Flutter Storefront SDK Implementation Plan

> Execute test-first. Each behavior task begins with a focused failing test, then the minimum
> implementation, then focused and full verification.

**Goal:** Publish a secure, lightweight, typed `crave_storefront_sdk` preview that covers every
reviewed public Storefront operation and is ready for external Flutter integration.

**Architecture:** A pure-Dart public facade delegates to one internal transport, session manager,
JSON decoder, and typed resource clients. A checked-in operation manifest makes route and security
coverage executable while the canonical server OpenAPI is completed.

**Toolchain:** Dart >=3.4, `package:http`, `package:test`, strict analyzer, GitHub Actions, pub.dev,
`pana`.

## Task 1: Package and contract guardrails

**Create:** `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, `.pubignore`
**Create:** `test/package_contract_test.dart`, `test/operation_manifest_test.dart`
**Create:** `tool/storefront_operations.json`

1. Write failing tests for package identity, one public entrypoint, no Flutter/native dependency,
   no path/Git dependencies, no API-key vocabulary in public examples, and exactly 50 unique
   operations.
2. Add package metadata and the operation manifest derived from exact platform route evidence.
3. Make the guardrails pass and commit the foundation.

## Task 2: Safe transport and errors

**Create:** `lib/src/http/transport.dart`, `lib/src/http/request_options.dart`
**Create:** `lib/src/errors.dart`, `lib/src/cancellation.dart`
**Test:** `test/http/transport_test.dart`, `test/errors_test.dart`

1. Write failing tests for URI validation, fixed namespace paths, segment encoding, managed-header
   stripping, anonymous auth, JWT auth, redirects, JSON/204 decoding, safe errors, request ID,
   timeout, cancellation, and network failure.
2. Implement the smallest internal transport with `http.AbortableRequest` and no public raw escape
   hatch.
3. Run focused tests, full tests, analysis, and format.

## Task 3: Session, revision, and idempotency core

**Create:** `lib/src/session/session.dart`, `lib/src/session/session_store.dart`
**Create:** `lib/src/session/in_memory_session_store.dart`, `lib/src/runtime/cart_runtime.dart`
**Test:** `test/session/session_store_test.dart`, `test/runtime/cart_runtime_test.dart`

1. Write failing tests for origin/merchant/location isolation, capability capture, revision parsing,
   mutation headers, stable keys, conflict refresh without retry, claim capability removal, delete
   cleanup, terminal cleanup, concurrent ordering-session coalescing, delayed-response cleanup
   races, and queued timeout/cancellation without late HTTP requests.
2. Implement the single shared lifecycle owner used by all cart-related clients.
3. Verify no service duplicates header, storage, ETag, or key logic.

## Task 4: DTOs and JSON codecs

**Create:** `lib/src/models/*.dart`, `lib/src/json/json_reader.dart`
**Create:** `test/fixtures/*.json`
**Test:** `test/models/*_test.dart`

1. Add sanitized runtime fixtures and failing parse/serialize tests for merchant/location/catalog,
   cart, customer/order/address, checkout/receipt/rating, analytics, and loyalty families.
2. Implement immutable response models and allowlisted request models with one shared decoder.
3. Add malformed/unknown/additive-field tests and ensure decoder errors contain no sensitive value.

## Task 5: Typed resource clients

**Create:** `lib/src/resources/*.dart`, `lib/src/client.dart`
**Create:** `lib/crave_storefront_sdk.dart`
**Test:** `test/resources/*_test.dart`, `test/client_test.dart`

1. Add one failing contract test per operation family, proving exact method/path/query/body/headers and
   decoded result.
2. Implement all 49 JSON operations through the shared runtime; keep the location redirect as an
   explicit browser-navigation exclusion.
3. Prove every non-excluded manifest operation has one typed method and every typed method has one
   manifest entry.
4. Remove deprecated/duplicate aliases before the first release.

## Task 6: External developer experience

**Modify:** `README.md`
**Create:** `CHANGELOG.md`, `SECURITY.md`, `CONTRIBUTING.md`, `example/main.dart`
**Create:** `tool/flutter_consumer/**`
**Test:** `test/documentation_contract_test.dart`

1. Write failing doc-contract tests for exact pinning, explicit base URI/merchant, secure session-store
   guidance, safe token provider, cancellation/error/conflict handling, and no raw HTTP/API key.
2. Add concise installation, quickstart, resource map, security, storage, and migration expectations.
3. Add a minimal compilable package example and a disposable Flutter consumer compile/test fixture;
   do not build the future storefront example application.
4. Document every public member and run `dart doc` without warnings.

## Task 7: CI, security, and release automation

**Create:** `.github/workflows/ci.yml`, `.github/workflows/publish.yml`
**Create:** `tool/verify.sh`, `tool/check_secrets.sh`

1. Add pinned-action CI for Dart 3.4 and stable: format, fatal-info analyze, tests, JavaScript compile
   and Chrome runtime checks, docs, advisory and outdated review, dry-run package, inventory check,
   and secret scan.
2. Add current-stable Flutter consumer verification.
3. Add tag-only pub.dev OIDC workflow scoped to `contents: read` and `id-token: write`, using the
   protected `pub.dev` environment. It becomes active only after the manual first release and pub.dev
   configuration.
4. Enable Dependabot, private vulnerability reporting, security advisories, and protected releases.

## Task 8: Review/fix and publication

1. Run the full local suite and current `pana`; inspect the exact archive file list.
2. Perform independent contract, security, API/DX, and release reviews. Fix every justified finding,
   rerun focused/full gates, and repeat until no P0/P1 issues remain.
3. Push the feature branch, open a PR, inspect all changed files/checks/threads, and normally merge the
   exact reviewed head to `main`.
4. Re-run release gates from a clean `main` checkout. Verify version/changelog/tag alignment.
5. Publish `0.1.0` interactively from the exact tag using the organization-controlled pub.dev account.
6. Transfer to the verified `craveup.com` publisher, enable OIDC with the protected environment, and
   verify pub.dev docs, score, audit log, source archive, install, and a clean Flutter consumer.

If authentication or verified-publisher ownership is unavailable, stop at the external boundary:
leave the implementation merged and release-ready, do not use a personal account silently, and
report the single exact owner action needed.
