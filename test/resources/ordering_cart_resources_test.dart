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
      fulfillmentMethod: FulfillmentMethod.takeout,
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
          fulfillmentMethod: FulfillmentMethod.takeout,
          channel: OrderChannel.app,
          existingCartId: 'cart_01',
        ),
      ),
      throwsA(isA<StorefrontConfigurationException>()),
    );

    expect(requestCount, 0);
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
        (_) async => http.Response(jsonEncode(_cartJson(revision: 3)), 200),
      ),
    );

    await client.carts.delete('location_01', 'cart_01');
    expect(await store.read(_scope()), isNull);
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
