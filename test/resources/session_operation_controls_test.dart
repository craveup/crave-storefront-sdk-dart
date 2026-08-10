import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('session reads obey the client operation timeout', () async {
    var requestCount = 0;
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: _NeverSessionStore(),
      timeout: const Duration(milliseconds: 5),
      httpClient: MockClient((_) async {
        requestCount += 1;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      client.carts
          .get('location_01', 'cart_01')
          .timeout(const Duration(milliseconds: 100)),
      throwsA(isA<StorefrontTimeoutException>()),
    );
    expect(requestCount, 0);
    client.close();
  });

  test('session reads obey caller cancellation', () async {
    var requestCount = 0;
    final cancellation = StorefrontCancellationToken();
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: _NeverSessionStore(),
      httpClient: MockClient((_) async {
        requestCount += 1;
        return http.Response('{}', 200);
      }),
    );

    final pending = client.carts.get(
      'location_01',
      'cart_01',
      options: StorefrontRequestOptions(cancellationToken: cancellation),
    );
    cancellation.cancel();

    await expectLater(
      pending.timeout(const Duration(milliseconds: 100)),
      throwsA(isA<StorefrontRequestCancelledException>()),
    );
    expect(requestCount, 0);
    client.close();
  });

  test('ordering bootstrap includes session reads in its deadline', () async {
    var requestCount = 0;
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: _NeverSessionStore(),
      timeout: const Duration(milliseconds: 5),
      httpClient: MockClient((_) async {
        requestCount += 1;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      client.orderingSessions
          .start(
            'location_01',
            StartOrderingSessionRequest(fulfillmentMethod: 'takeout'),
          )
          .timeout(const Duration(milliseconds: 100)),
      throwsA(isA<StorefrontTimeoutException>()),
    );
    expect(requestCount, 0);
    client.close();
  });

  test('session adapter errors are typed and redaction-safe', () async {
    const privateValue = 'private-storage-path-and-capability';
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: _ThrowingReadStore(privateValue),
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(
      client.carts.get('location_01', 'cart_01'),
      throwsA(
        isA<StorefrontSessionException>()
            .having(
              (error) => error.operationMayHaveSucceeded,
              'operationMayHaveSucceeded',
              isFalse,
            )
            .having(
              (error) => error.toString(),
              'safe string',
              isNot(contains(privateValue)),
            ),
      ),
    );
    client.close();
  });

  test('post-response persistence failures expose the stable replay key',
      () async {
    const privateValue = 'private-storage-path-and-capability';
    const stableKey = 'same-logical-mutation-0001';
    final scope = StorefrontSessionScope(
      apiOrigin: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      locationId: 'location_01',
    );
    final store = _FailingWriteStore(
      StorefrontCartSession(
        scope: scope,
        cartId: 'cart_01',
        accessToken: 'cart-capability',
        revision: 1,
      ),
      privateValue,
    );
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(_cartFixture(revision: 2)),
          200,
          headers: {'etag': '"cart-2"'},
        ),
      ),
    );

    await expectLater(
      client.carts.update(
        'location_01',
        'cart_01',
        const UpdateCartRequest(fulfillmentMethod: FulfillmentMethod.delivery),
        options: const StorefrontRequestOptions(
          idempotencyKey: stableKey,
        ),
      ),
      throwsA(
        isA<StorefrontSessionException>()
            .having(
              (error) => error.operationMayHaveSucceeded,
              'operationMayHaveSucceeded',
              isTrue,
            )
            .having(
              (error) => error.retryIdempotencyKey,
              'retryIdempotencyKey',
              stableKey,
            )
            .having(
              (error) => error.toString(),
              'safe string',
              isNot(contains(privateValue)),
            ),
      ),
    );
    client.close();
  });

  test('ordering persistence failure identifies an ambiguous remote success',
      () async {
    const stableKey = 'same-ordering-session-0001';
    final store = _WriteOnlyFailStore('private-ordering-storage-value');
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'cart': _cartFixture(revision: 0),
            'cartAccessToken': 'cart-capability',
          }),
          201,
          headers: {'etag': '"cart-0"'},
        ),
      ),
    );

    await expectLater(
      client.orderingSessions.start(
        'location_01',
        StartOrderingSessionRequest.fresh(fulfillmentMethod: 'takeout'),
        options: const StorefrontRequestOptions(idempotencyKey: stableKey),
      ),
      throwsA(
        isA<StorefrontSessionException>()
            .having(
              (error) => error.operationMayHaveSucceeded,
              'operationMayHaveSucceeded',
              isTrue,
            )
            .having(
              (error) => error.retryIdempotencyKey,
              'retryIdempotencyKey',
              stableKey,
            ),
      ),
    );
    client.close();
  });

  test('rating cleanup failure identifies an ambiguous remote success',
      () async {
    const stableKey = 'same-rating-submit-0001';
    final store = _FailingDeleteStore(
      StorefrontCartSession(
        scope: StorefrontSessionScope(
          apiOrigin: Uri.parse('https://api.example.test'),
          merchantSlug: 'example-merchant',
          locationId: 'location_01',
        ),
        cartId: 'cart_01',
        accessToken: 'cart-capability',
        revision: 1,
      ),
    );
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      httpClient: MockClient(
        (_) async => http.Response(
          '{"success":true,"id":"rating_01"}',
          200,
        ),
      ),
    );

    await expectLater(
      client.ratings.submit(
        'location_01',
        'cart_01',
        RatingRequest(rating: 5),
        options: const StorefrontRequestOptions(idempotencyKey: stableKey),
      ),
      throwsA(
        isA<StorefrontSessionException>()
            .having(
              (error) => error.operationMayHaveSucceeded,
              'operationMayHaveSucceeded',
              isTrue,
            )
            .having(
              (error) => error.retryIdempotencyKey,
              'retryIdempotencyKey',
              stableKey,
            ),
      ),
    );
    client.close();
  });

  test('post-response session timeout retains the stable replay key', () async {
    const stableKey = 'same-session-timeout-0001';
    final store = _HangingWriteStore(_session());
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(_cartFixture(revision: 2)),
          200,
          headers: {'etag': '"cart-2"'},
        ),
      ),
    );

    final pending = client.carts.update(
      'location_01',
      'cart_01',
      const UpdateCartRequest(fulfillmentMethod: FulfillmentMethod.delivery),
      options: const StorefrontRequestOptions(idempotencyKey: stableKey),
    );
    await store.writeStarted.future.timeout(const Duration(seconds: 1));
    await expectLater(
      pending,
      throwsA(
        isA<StorefrontTimeoutException>().having(
          (error) => error.retryIdempotencyKey,
          'retryIdempotencyKey',
          stableKey,
        ),
      ),
    );
    client.close();
  });

  test('post-response timeout exposes an SDK-generated replay key', () async {
    final store = _HangingWriteStore(_session());
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(_cartFixture(revision: 2)),
          200,
          headers: {'etag': '"cart-2"'},
        ),
      ),
    );

    final pending = client.carts.update(
      'location_01',
      'cart_01',
      const UpdateCartRequest(fulfillmentMethod: FulfillmentMethod.delivery),
    );
    await store.writeStarted.future.timeout(const Duration(seconds: 1));
    await expectLater(
      pending,
      throwsA(
        isA<StorefrontTimeoutException>().having(
          (error) => error.retryIdempotencyKey,
          'retryIdempotencyKey',
          matches(RegExp(r'^[A-Za-z0-9._:-]{16,128}$')),
        ),
      ),
    );
    client.close();
  });

  test('post-response session cancellation retains the stable replay key',
      () async {
    const stableKey = 'same-session-cancel-0001';
    final cancellation = StorefrontCancellationToken();
    final store = _HangingWriteStore(_session());
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(_cartFixture(revision: 2)),
          200,
          headers: {'etag': '"cart-2"'},
        ),
      ),
    );
    final pending = client.carts.update(
      'location_01',
      'cart_01',
      const UpdateCartRequest(fulfillmentMethod: FulfillmentMethod.delivery),
      options: StorefrontRequestOptions(
        idempotencyKey: stableKey,
        cancellationToken: cancellation,
      ),
    );
    await store.writeStarted.future;
    cancellation.cancel();

    await expectLater(
      pending,
      throwsA(
        isA<StorefrontRequestCancelledException>().having(
          (error) => error.retryIdempotencyKey,
          'retryIdempotencyKey',
          stableKey,
        ),
      ),
    );
    client.close();
  });
}

StorefrontCartSession _session() => StorefrontCartSession(
      scope: StorefrontSessionScope(
        apiOrigin: Uri.parse('https://api.example.test'),
        merchantSlug: 'example-merchant',
        locationId: 'location_01',
      ),
      cartId: 'cart_01',
      accessToken: 'cart-capability',
      revision: 1,
    );

Map<String, Object?> _cartFixture({required int revision}) {
  final decoded = jsonDecode(
    File('test/fixtures/cart.json').readAsStringSync(),
  ) as Map<String, Object?>;
  return <String, Object?>{...decoded, 'revision': revision};
}

final class _NeverSessionStore implements StorefrontSessionStore {
  final Completer<StorefrontCartSession?> _read = Completer();

  @override
  Future<StorefrontCartSession?> read(StorefrontSessionScope scope) =>
      _read.future;

  @override
  Future<void> write(StorefrontCartSession session) => Completer<void>().future;

  @override
  Future<void> delete(StorefrontSessionScope scope) => Completer<void>().future;
}

final class _ThrowingReadStore implements StorefrontSessionStore {
  _ThrowingReadStore(this.privateValue);

  final String privateValue;

  @override
  Future<StorefrontCartSession?> read(StorefrontSessionScope scope) async =>
      throw StateError(privateValue);

  @override
  Future<void> write(StorefrontCartSession session) async {}

  @override
  Future<void> delete(StorefrontSessionScope scope) async {}
}

final class _FailingWriteStore implements StorefrontSessionStore {
  _FailingWriteStore(this.session, this.privateValue);

  final StorefrontCartSession session;
  final String privateValue;

  @override
  Future<StorefrontCartSession?> read(StorefrontSessionScope scope) async =>
      session;

  @override
  Future<void> write(StorefrontCartSession session) async =>
      throw StateError(privateValue);

  @override
  Future<void> delete(StorefrontSessionScope scope) async {}
}

final class _WriteOnlyFailStore implements StorefrontSessionStore {
  _WriteOnlyFailStore(this.privateValue);

  final String privateValue;

  @override
  Future<StorefrontCartSession?> read(StorefrontSessionScope scope) async =>
      null;

  @override
  Future<void> write(StorefrontCartSession session) async =>
      throw StateError(privateValue);

  @override
  Future<void> delete(StorefrontSessionScope scope) async {}
}

final class _FailingDeleteStore implements StorefrontSessionStore {
  _FailingDeleteStore(this.session);

  final StorefrontCartSession session;

  @override
  Future<StorefrontCartSession?> read(StorefrontSessionScope scope) async =>
      session;

  @override
  Future<void> write(StorefrontCartSession session) async {}

  @override
  Future<void> delete(StorefrontSessionScope scope) async =>
      throw StateError('private-rating-storage-value');
}

final class _HangingWriteStore implements StorefrontSessionStore {
  _HangingWriteStore(this.session);

  final StorefrontCartSession session;
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> _write = Completer<void>();

  @override
  Future<StorefrontCartSession?> read(StorefrontSessionScope scope) async =>
      session;

  @override
  Future<void> write(StorefrontCartSession session) {
    if (!writeStarted.isCompleted) {
      writeStarted.complete();
    }
    return _write.future;
  }

  @override
  Future<void> delete(StorefrontSessionScope scope) async {}
}
