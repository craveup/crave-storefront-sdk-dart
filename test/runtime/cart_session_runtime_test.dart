import 'dart:async';

import 'package:crave_storefront_sdk/src/runtime/cart_session_runtime.dart';
import 'package:crave_storefront_sdk/src/runtime/request_runtime.dart';
import 'package:crave_storefront_sdk/src/session/session.dart';
import 'package:crave_storefront_sdk/src/session/session_store.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryStorefrontSessionStore store;
  late CartSessionRuntime runtime;

  setUp(() {
    store = InMemoryStorefrontSessionStore();
    runtime = CartSessionRuntime(
      apiOrigin: Uri.parse('https://api.example.test'),
      merchantSlug: 'merchant-a',
      sessionStore: store,
      idempotencyKeyGenerator: StorefrontIdempotencyKeyGenerator(),
    );
  });

  test('builds one cart context from the correctly scoped session', () async {
    final scope = runtime.scopeFor('location-a');
    await store.write(
      StorefrontCartSession(
        scope: scope,
        cartId: 'cart-a',
        accessToken: 'cart-capability',
        revision: 7,
      ),
    );

    final context = await runtime.contextFor(
      locationId: 'location-a',
      cartId: 'cart-a',
      idempotent: true,
      revisionRequired: true,
    );

    expect(context.accessToken, 'cart-capability');
    expect(context.revision, 7);
    expect(context.idempotencyKey, matches(RegExp(r'^sf_')));

    final wrongCart = await runtime.contextFor(
      locationId: 'location-a',
      cartId: 'cart-b',
      idempotent: false,
      revisionRequired: false,
    );
    expect(wrongCart.accessToken, isNull);
    expect(wrongCart.revision, isNull);
  });

  test('caller overrides remain stable and do not create a second key',
      () async {
    const options = StorefrontRequestOptions(
      idempotencyKey: 'caller_stable_key_123',
      revision: 11,
    );

    final context = await runtime.contextFor(
      locationId: 'location-a',
      cartId: 'cart-a',
      idempotent: true,
      revisionRequired: true,
      options: options,
    );

    expect(context.idempotencyKey, options.idempotencyKey);
    expect(context.revision, options.revision);
  });

  test('captures returned cart identity and preserves a resumed capability',
      () async {
    final scope = runtime.scopeFor('location-a');
    await runtime.capture(
      locationId: 'location-a',
      cartId: 'old-cart',
      accessToken: 'old-capability',
      revision: 2,
    );

    await runtime.capture(
      locationId: 'location-a',
      cartId: 'old-cart',
      revision: 3,
    );
    expect((await store.read(scope))?.accessToken, 'old-capability');
    expect((await store.read(scope))?.revision, 3);

    await runtime.capture(
      locationId: 'location-a',
      cartId: 'replacement-cart',
      accessToken: 'replacement-capability',
      revision: 0,
    );
    expect((await store.read(scope))?.cartId, 'replacement-cart');
    expect((await store.read(scope))?.accessToken, 'replacement-capability');
  });

  test(
      'persists only newer response revisions and applies claim/delete transitions',
      () async {
    final scope = runtime.scopeFor('location-a');
    await runtime.capture(
      locationId: 'location-a',
      cartId: 'cart-a',
      accessToken: 'cart-capability',
      revision: 4,
    );

    await runtime.persistRevision(
      locationId: 'location-a',
      cartId: 'cart-a',
      etag: 'W/"cart-3"',
      fallback: 3,
    );
    expect((await store.read(scope))?.revision, 4);

    await runtime.persistRevision(
      locationId: 'location-a',
      cartId: 'cart-a',
      etag: '"cart-5"',
      fallback: 2,
    );
    expect((await store.read(scope))?.revision, 5);

    await runtime.removeCapability(
      locationId: 'location-a',
      cartId: 'cart-a',
    );
    expect((await store.read(scope))?.accessToken, isNull);
    expect((await store.read(scope))?.cartId, 'cart-a');

    await runtime.clear(locationId: 'location-a', cartId: 'different-cart');
    expect(await store.read(scope), isNotNull);
    await runtime.clear(locationId: 'location-a', cartId: 'cart-a');
    expect(await store.read(scope), isNull);
  });

  test('coalesces identical in-flight ordering starts and releases failures',
      () async {
    final coordinator = OrderingSessionCoordinator();
    final pending = Completer<String>();
    var calls = 0;

    Future<String> operation() {
      calls += 1;
      return pending.future;
    }

    final first = coordinator.run('same-request', operation);
    final second = coordinator.run('same-request', operation);
    expect(identical(first, second), isTrue);
    expect(calls, 1);

    pending.complete('cart-a');
    expect(await first, 'cart-a');
    expect(await second, 'cart-a');

    final third = coordinator.run('same-request', () async => 'cart-b');
    expect(await third, 'cart-b');
    expect(calls, 1);
  });
}
