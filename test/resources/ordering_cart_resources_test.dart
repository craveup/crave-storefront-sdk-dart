import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('ordering starts coalesce and capture the returned cart session',
      () async {
    final store = InMemoryStorefrontSessionStore();
    final requests = <http.Request>[];
    final pending = <Future<StartOrderingSessionResult>>[];
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      customerTokenProvider: () async => 'customer-token',
      sessionStore: store,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'cart': _cartJson(revision: 1),
            'cartAccessToken': 'cart-capability',
          }),
          201,
          headers: {'etag': 'W/"cart-1"'},
        );
      }),
    );
    final request = StartOrderingSessionRequest(
      fulfillmentMethod: 'takeout',
      channel: OrderChannel.app,
    );

    pending
      ..add(client.orderingSessions.start('location_01', request))
      ..add(client.orderingSessions.start('location_01', request));
    final results = await Future.wait(pending);

    expect(requests, hasLength(1));
    expect(results[0].cart.id, 'cart_01');
    expect(results[1].cart.id, 'cart_01');
    expect(requests.single.headers['authorization'], 'Bearer customer-token');
    expect(
      requests.single.headers['idempotency-key'],
      matches(RegExp(r'^[A-Za-z0-9._:-]{16,128}$')),
    );
    final stored = await store.read(
      StorefrontSessionScope(
        apiOrigin: Uri.parse('https://api.example.test'),
        merchantSlug: 'example-merchant',
        locationId: 'location_01',
      ),
    );
    expect(stored?.cartId, 'cart_01');
    expect(stored?.accessToken, 'cart-capability');
    expect(stored?.revision, 1);
    client.close();
  });

  test('ordering resume requires a known or caller-supplied cart revision',
      () async {
    var requestCount = 0;
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      customerTokenProvider: () async => 'customer-token',
      httpClient: MockClient((_) async {
        requestCount += 1;
        return http.Response('{}', 500);
      }),
    );

    await expectLater(
      client.orderingSessions.start(
        'location_01',
        StartOrderingSessionRequest(
          fulfillmentMethod: 'takeout',
          channel: OrderChannel.app,
          existingCartId: 'cart_01',
        ),
      ),
      throwsA(isA<StorefrontConfigurationException>()),
    );

    expect(requestCount, 0);
    client.close();
  });

  test('cart recommendations return an unmodifiable list', () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store, revision: 3);
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(<Object?>[
            <String, Object?>{
              'id': 'product_01',
              'name': 'Tea',
              'price': '4.00',
              'images': <Object?>[],
              'modifierIds': <Object?>[],
            },
          ]),
          200,
          headers: {'etag': '"cart-4"'},
        ),
      ),
    );

    final recommendations = await client.carts.listRecommendedProducts(
      'location_01',
      'cart_01',
    );

    expect(recommendations.single.id, 'product_01');
    expect(
      () => recommendations[0] = recommendations[0],
      throwsUnsupportedError,
    );
    client.close();
  });

  test('ordering rejects a returned cart from another location', () async {
    final store = InMemoryStorefrontSessionStore();
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'cart': {
              ..._cartJson(revision: 1),
              'locationId': 'another_location',
            },
            'cartAccessToken': 'wrong-location-capability',
          }),
          201,
          headers: {'etag': '"cart-1"'},
        ),
      ),
    );

    await expectLater(
      client.orderingSessions.start(
        'location_01',
        StartOrderingSessionRequest.fresh(
          fulfillmentMethod: 'takeout',
        ),
      ),
      throwsA(isA<StorefrontDecodingException>()),
    );

    expect(await store.read(_scope()), isNull);
    client.close();
  });

  test('cart mutations centralize capability, revision, and idempotency',
      () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store, revision: 3);
    late http.Request captured;
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(_cartJson(revision: 4)),
          200,
          headers: {'etag': '"cart-4"'},
        );
      }),
    );

    final cart = await client.carts.addItem(
      'location_01',
      'cart_01',
      AddCartItemRequest(
        productId: 'product_01',
        quantity: 1,
        itemUnavailableAction: ItemUnavailableAction.removeItem,
        selections: const [],
      ),
    );

    expect(captured.method, 'POST');
    expect(
      captured.url.path,
      '/api/v1/storefront/locations/location_01/carts/cart_01/items',
    );
    expect(captured.headers['x-cart-token'], 'cart-capability');
    expect(captured.headers['if-match'], '"cart-3"');
    expect(
      captured.headers['idempotency-key'],
      matches(RegExp(r'^[A-Za-z0-9._:-]{16,128}$')),
    );
    expect((jsonDecode(captured.body) as Map)['productId'], 'product_01');
    expect(cart.revision, 4);
    expect(
      (await store.read(_scope()))?.revision,
      4,
    );
    client.close();
  });

  test('cart conflicts refresh revision once, never retry the mutation',
      () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store, revision: 4);
    var patchCalls = 0;
    var getCalls = 0;
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      httpClient: MockClient((request) async {
        if (request.method == 'PATCH') {
          patchCalls += 1;
          return http.Response(
            jsonEncode({
              'code': 'CART_CONFLICT',
              'message': 'Stale revision.',
              'requestId': 'req_conflict',
            }),
            409,
          );
        }
        getCalls += 1;
        return http.Response(
          jsonEncode(_cartJson(revision: 9)),
          200,
          headers: {'etag': 'W/"cart-9"'},
        );
      }),
    );

    await expectLater(
      client.carts.update(
        'location_01',
        'cart_01',
        const UpdateCartRequest(fulfillmentMethod: FulfillmentMethod.delivery),
      ),
      throwsA(
        isA<StorefrontApiException>().having(
          (error) => error.code,
          'code',
          'CART_CONFLICT',
        ),
      ),
    );

    expect(patchCalls, 1);
    expect(getCalls, 1);
    expect((await store.read(_scope()))?.revision, 9);
    client.close();
  });

  test('analytics uses the matching capability and claim removes it', () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store, revision: 2);
    final requests = <http.Request>[];
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      customerTokenProvider: () async => 'customer-token',
      sessionStore: store,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/analytics-events')) {
          return http.Response('{"status":"accepted"}', 202);
        }
        return http.Response(
          jsonEncode(_cartJson(revision: 3)),
          200,
          headers: {'etag': '"cart-3"'},
        );
      }),
    );

    final analytics = await client.analyticsEvents.submit(
      'location_01',
      AnalyticsEventRequest(
        cartId: 'cart_01',
        eventType: AnalyticsEventType.cartView,
      ),
    );
    final claimed = await client.carts.claim('location_01', 'cart_01');

    expect(analytics.status, 'accepted');
    expect(claimed.revision, 3);
    expect(requests[0].headers['x-cart-token'], 'cart-capability');
    expect(requests[1].headers['x-cart-token'], 'cart-capability');
    expect(requests[1].headers['authorization'], 'Bearer customer-token');
    expect((await store.read(_scope()))?.accessToken, isNull);
    expect((await store.read(_scope()))?.cartId, 'cart_01');
    client.close();
  });

  test('successful cart deletion clears only the matching session', () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store, revision: 2);
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(_cartJson(revision: 3)),
          200,
          headers: {'etag': '"cart-3"'},
        ),
      ),
    );

    await client.carts.delete('location_01', 'cart_01');
    expect(await store.read(_scope()), isNull);
    client.close();
  });

  test('serializes a delayed cart read before deletion cleanup', () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store, revision: 1);
    final getStarted = Completer<void>();
    final releaseGet = Completer<void>();
    final deleteStarted = Completer<void>();
    late http.Request deleteRequest;
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          getStarted.complete();
          await releaseGet.future;
          return http.Response(
            jsonEncode(_cartJson(revision: 2)),
            200,
            headers: {'etag': '"cart-2"'},
          );
        }
        deleteRequest = request;
        deleteStarted.complete();
        return http.Response(
          jsonEncode(_cartJson(revision: 3)),
          200,
          headers: {'etag': '"cart-3"'},
        );
      }),
    );

    final pendingGet = client.carts.get('location_01', 'cart_01');
    await getStarted.future;
    final pendingDelete = client.carts.delete('location_01', 'cart_01');
    final deleteOvertookRead = await Future.any<bool>([
      deleteStarted.future.then((_) => true),
      Future<bool>.delayed(const Duration(milliseconds: 25), () => false),
    ]);
    releaseGet.complete();
    await pendingGet;
    await pendingDelete;

    expect(deleteOvertookRead, isFalse);
    expect(deleteRequest.headers['if-match'], '"cart-2"');
    expect(await store.read(_scope()), isNull);
    client.close();
  });

  test('serializes a resumed ordering session before deletion cleanup',
      () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store, revision: 1);
    final orderingStarted = Completer<void>();
    final releaseOrdering = Completer<void>();
    final deleteStarted = Completer<void>();
    late http.Request deleteRequest;
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/ordering-sessions')) {
          orderingStarted.complete();
          await releaseOrdering.future;
          return http.Response(
            jsonEncode({
              'cart': _cartJson(revision: 2),
              'cartAccessToken': 'resumed-capability',
            }),
            201,
            headers: {'etag': '"cart-2"'},
          );
        }
        deleteRequest = request;
        deleteStarted.complete();
        return http.Response(
          jsonEncode(_cartJson(revision: 3)),
          200,
          headers: {'etag': '"cart-3"'},
        );
      }),
    );

    final pendingOrdering = client.orderingSessions.start(
      'location_01',
      StartOrderingSessionRequest(
        fulfillmentMethod: 'takeout',
        existingCartId: 'cart_01',
      ),
    );
    await orderingStarted.future;
    final pendingDelete = client.carts.delete('location_01', 'cart_01');
    final deleteOvertookOrdering = await Future.any<bool>([
      deleteStarted.future.then((_) => true),
      Future<bool>.delayed(const Duration(milliseconds: 25), () => false),
    ]);
    releaseOrdering.complete();
    await pendingOrdering;
    await pendingDelete;

    expect(deleteOvertookOrdering, isFalse);
    expect(deleteRequest.headers['if-match'], '"cart-2"');
    expect(await store.read(_scope()), isNull);
    client.close();
  });

  test('serializes handoff exchange before deletion cleanup', () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store, revision: 1);
    final exchangeStarted = Completer<void>();
    final releaseExchange = Completer<void>();
    final deleteStarted = Completer<void>();
    late http.Request deleteRequest;
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/exchange')) {
          exchangeStarted.complete();
          await releaseExchange.future;
          return http.Response(
            jsonEncode({
              'cart': _cartJson(revision: 2),
              'cartAccessToken': 'exchanged-capability',
              'merchantSlug': 'example-merchant',
            }),
            200,
            headers: {'etag': '"cart-2"'},
          );
        }
        deleteRequest = request;
        deleteStarted.complete();
        return http.Response(
          jsonEncode(_cartJson(revision: 3)),
          200,
          headers: {'etag': '"cart-3"'},
        );
      }),
    );

    final pendingExchange = client.checkout.exchangeHandoff(
      'location_01',
      'cart_01',
      'checkout-handoff-capability',
      options: const StorefrontRequestOptions(
        idempotencyKey: 'checkout-exchange-race-0001',
      ),
    );
    await exchangeStarted.future;
    final pendingDelete = client.carts.delete('location_01', 'cart_01');
    final deleteOvertookExchange = await Future.any<bool>([
      deleteStarted.future.then((_) => true),
      Future<bool>.delayed(const Duration(milliseconds: 25), () => false),
    ]);
    releaseExchange.complete();
    await pendingExchange;
    await pendingDelete;

    expect(deleteOvertookExchange, isFalse);
    expect(deleteRequest.headers['if-match'], '"cart-2"');
    expect(await store.read(_scope()), isNull);
    client.close();
  });

  test('does not send a queued cart mutation after its timeout', () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store, revision: 1);
    final getStarted = Completer<void>();
    final releaseGet = Completer<void>();
    final requests = <http.Request>[];
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method != 'GET') {
          return http.Response(
            jsonEncode(_cartJson(revision: 3)),
            200,
            headers: {'etag': '"cart-3"'},
          );
        }
        getStarted.complete();
        await releaseGet.future;
        return http.Response(
          jsonEncode(_cartJson(revision: 2)),
          200,
          headers: {'etag': '"cart-2"'},
        );
      }),
    );

    final pendingGet = client.carts.get('location_01', 'cart_01');
    await getStarted.future;
    final pendingDelete = client.carts.delete(
      'location_01',
      'cart_01',
      options: const StorefrontRequestOptions(
        timeout: Duration(milliseconds: 10),
      ),
    );

    await expectLater(
        pendingDelete, throwsA(isA<StorefrontTimeoutException>()));
    releaseGet.complete();
    await pendingGet;
    await Future<void>.delayed(const Duration(milliseconds: 25));

    expect(requests, hasLength(1));
    expect((await store.read(_scope()))?.revision, 2);
    client.close();
  });
}

Map<String, Object?> _cartJson({required int revision}) {
  final source = jsonDecode(File('test/fixtures/cart.json').readAsStringSync())
      as Map<String, Object?>;
  return {...source, 'revision': revision};
}

StorefrontSessionScope _scope() => StorefrontSessionScope(
      apiOrigin: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      locationId: 'location_01',
    );

Future<void> _seedSession(
  InMemoryStorefrontSessionStore store, {
  required int revision,
}) =>
    store.write(
      StorefrontCartSession(
        scope: _scope(),
        cartId: 'cart_01',
        accessToken: 'cart-capability',
        revision: revision,
      ),
    );
