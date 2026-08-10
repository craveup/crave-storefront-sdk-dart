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

  test('ignores expired capabilities except for deletion replay', () async {
    final fixedNow = DateTime.utc(2026, 8, 10, 12);
    runtime = CartSessionRuntime(
      apiOrigin: Uri.parse('https://api.example.test'),
      merchantSlug: 'merchant-a',
      sessionStore: store,
      idempotencyKeyGenerator: StorefrontIdempotencyKeyGenerator(),
      now: () => fixedNow,
    );
    final scope = runtime.scopeFor('location-a');
    await store.write(
      StorefrontCartSession(
        scope: scope,
        cartId: 'cart-a',
        accessToken: 'expired-capability',
        revision: 7,
        expiresAt: fixedNow.subtract(const Duration(seconds: 1)),
      ),
    );

    final normal = await runtime.contextFor(
      locationId: 'location-a',
      cartId: 'cart-a',
      idempotent: false,
      revisionRequired: true,
    );
    final deletionReplay = await runtime.contextFor(
      locationId: 'location-a',
      cartId: 'cart-a',
      idempotent: true,
      revisionRequired: true,
      allowExpiredSession: true,
    );

    expect(normal.accessToken, isNull);
    expect(normal.revision, isNull);
    expect(deletionReplay.accessToken, 'expired-capability');
    expect(deletionReplay.revision, 7);
    expect(await store.read(scope), isNotNull);
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

  test('never trusts a session returned for a different scope', () async {
    final requestedScope = runtime.scopeFor('location-a');
    final mismatched = StorefrontCartSession(
      scope: StorefrontSessionScope(
        apiOrigin: Uri.parse('https://another-api.example.test'),
        merchantSlug: 'merchant-b',
        locationId: 'location-b',
      ),
      cartId: 'cart-a',
      accessToken: 'wrong-scope-capability',
      revision: 9,
    );
    final adversarialStore = _AdversarialSessionStore(mismatched);
    runtime = CartSessionRuntime(
      apiOrigin: Uri.parse('https://api.example.test'),
      merchantSlug: 'merchant-a',
      sessionStore: adversarialStore,
      idempotencyKeyGenerator: StorefrontIdempotencyKeyGenerator(),
    );

    final context = await runtime.contextFor(
      locationId: 'location-a',
      cartId: 'cart-a',
      idempotent: false,
      revisionRequired: true,
    );
    await runtime.capture(
      locationId: 'location-a',
      cartId: 'cart-a',
      revision: 1,
    );
    await runtime.clear(locationId: 'location-a', cartId: 'cart-a');

    expect(context.accessToken, isNull);
    expect(context.revision, isNull);
    expect(adversarialStore.writes, hasLength(1));
    expect(adversarialStore.writes.single.scope, requestedScope);
    expect(adversarialStore.writes.single.accessToken, isNull);
    expect(adversarialStore.deleteCount, 0);
  });

  test('serializes revision persistence with capability removal', () async {
    final scope = runtime.scopeFor('location-a');
    final gatedStore = _GatedSessionStore(
      StorefrontCartSession(
        scope: scope,
        cartId: 'cart-a',
        accessToken: 'cart-capability',
        revision: 1,
      ),
    )..gateRevisionWrite(2);
    runtime = CartSessionRuntime(
      apiOrigin: Uri.parse('https://api.example.test'),
      merchantSlug: 'merchant-a',
      sessionStore: gatedStore,
      idempotencyKeyGenerator: StorefrontIdempotencyKeyGenerator(),
    );

    final revisionWrite = runtime.persistRevision(
      locationId: 'location-a',
      cartId: 'cart-a',
      etag: '"cart-2"',
      fallback: 2,
    );
    await gatedStore.writeStarted.future;
    final removal = runtime.removeCapability(
      locationId: 'location-a',
      cartId: 'cart-a',
    );
    await Future<void>.delayed(Duration.zero);
    gatedStore.releaseWrite();
    await Future.wait([revisionWrite, removal]);

    expect(gatedStore.session?.revision, 2);
    expect(gatedStore.session?.accessToken, isNull);
  });

  test('serializes clearing an old cart with capturing its replacement',
      () async {
    final scope = runtime.scopeFor('location-a');
    final gatedStore = _GatedSessionStore(
      StorefrontCartSession(
        scope: scope,
        cartId: 'cart-a',
        accessToken: 'old-capability',
        revision: 1,
      ),
    )..gateDelete();
    runtime = CartSessionRuntime(
      apiOrigin: Uri.parse('https://api.example.test'),
      merchantSlug: 'merchant-a',
      sessionStore: gatedStore,
      idempotencyKeyGenerator: StorefrontIdempotencyKeyGenerator(),
    );

    final clearing = runtime.clear(
      locationId: 'location-a',
      cartId: 'cart-a',
    );
    await gatedStore.deleteStarted.future;
    final capture = runtime.capture(
      locationId: 'location-a',
      cartId: 'cart-b',
      accessToken: 'new-capability',
      revision: 0,
    );
    await Future<void>.delayed(Duration.zero);
    gatedStore.releaseDelete();
    await Future.wait([clearing, capture]);

    expect(gatedStore.session?.cartId, 'cart-b');
    expect(gatedStore.session?.accessToken, 'new-capability');
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

final class _AdversarialSessionStore implements StorefrontSessionStore {
  _AdversarialSessionStore(this.returnedSession);

  final StorefrontCartSession returnedSession;
  final List<StorefrontCartSession> writes = [];
  var deleteCount = 0;

  @override
  Future<StorefrontCartSession?> read(StorefrontSessionScope scope) async =>
      returnedSession;

  @override
  Future<void> write(StorefrontCartSession session) async {
    writes.add(session);
  }

  @override
  Future<void> delete(StorefrontSessionScope scope) async {
    deleteCount += 1;
  }
}

final class _GatedSessionStore implements StorefrontSessionStore {
  _GatedSessionStore(this.session);

  StorefrontCartSession? session;
  final writeStarted = Completer<void>();
  final deleteStarted = Completer<void>();
  Completer<void>? _writeRelease;
  Completer<void>? _deleteRelease;
  int? _gatedRevision;

  void gateRevisionWrite(int revision) {
    _gatedRevision = revision;
    _writeRelease = Completer<void>();
  }

  void releaseWrite() => _writeRelease?.complete();

  void gateDelete() {
    _deleteRelease = Completer<void>();
  }

  void releaseDelete() => _deleteRelease?.complete();

  @override
  Future<StorefrontCartSession?> read(StorefrontSessionScope scope) async =>
      session;

  @override
  Future<void> write(StorefrontCartSession next) async {
    if (next.revision == _gatedRevision && _writeRelease != null) {
      if (!writeStarted.isCompleted) writeStarted.complete();
      await _writeRelease!.future;
      _writeRelease = null;
    }
    session = next;
  }

  @override
  Future<void> delete(StorefrontSessionScope scope) async {
    if (_deleteRelease != null) {
      if (!deleteStarted.isCompleted) deleteStarted.complete();
      await _deleteRelease!.future;
      _deleteRelease = null;
    }
    session = null;
  }
}
