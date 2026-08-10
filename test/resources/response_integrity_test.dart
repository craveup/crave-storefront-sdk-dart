import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  for (final mismatch in ['cart', 'location']) {
    test('cart responses reject a mismatched $mismatch before persistence',
        () async {
      final store = InMemoryStorefrontSessionStore();
      await _seedSession(store);
      final responseCart = _cartFixture(revision: 2);
      responseCart[mismatch == 'cart' ? 'id' : 'locationId'] =
          mismatch == 'cart' ? 'cart_02' : 'location_02';
      final client = _client(
        store,
        (_) async => http.Response(
          jsonEncode(responseCart),
          200,
          headers: {'etag': '"cart-2"'},
        ),
      );

      await expectLater(
        client.carts.get('location_01', 'cart_01'),
        throwsA(isA<StorefrontDecodingException>()),
      );
      expect((await store.read(_scope()))?.revision, 1);
      client.close();
    });
  }

  test('cart responses require matching ETag and body revisions', () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store);
    final client = _client(
      store,
      (_) async => http.Response(
        jsonEncode(_cartFixture(revision: 2)),
        200,
        headers: {'etag': '"cart-999"'},
      ),
    );

    await expectLater(
      client.carts.update(
        'location_01',
        'cart_01',
        const UpdateCartRequest(fulfillmentMethod: FulfillmentMethod.delivery),
      ),
      throwsA(isA<StorefrontDecodingException>()),
    );
    expect((await store.read(_scope()))?.revision, 1);
    client.close();
  });

  test('header-only cart revision responses require a valid ETag', () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store);
    final client = _client(
      store,
      (request) async {
        if (request.url.path.endsWith('/payment-intent')) {
          return http.Response('{"clientSecret":"fixture-secret"}', 200);
        }
        if (request.url.path.endsWith('/products')) {
          return http.Response('[]', 200);
        }
        return http.Response('{"enabled":true}', 200);
      },
      customerTokenProvider: () async => 'customer-token',
    );

    await expectLater(
      client.checkout.createPaymentIntent('location_01', 'cart_01'),
      throwsA(isA<StorefrontDecodingException>()),
    );
    await expectLater(
      client.carts.listRecommendedProducts('location_01', 'cart_01'),
      throwsA(isA<StorefrontDecodingException>()),
    );
    await expectLater(
      client.loyalty.getQuote('location_01', 'cart_01'),
      throwsA(isA<StorefrontDecodingException>()),
    );
    expect((await store.read(_scope()))?.revision, 1);
    client.close();
  });

  for (final operation in ['redeem', 'cancel']) {
    for (final mismatch in ['cart', 'location']) {
      test('loyalty $operation rejects a mismatched $mismatch', () async {
        const stableKey = 'same-loyalty-mutation-0001';
        final store = InMemoryStorefrontSessionStore();
        await _seedSession(store);
        final responseCart = _cartFixture(revision: 2);
        responseCart[mismatch == 'cart' ? 'id' : 'locationId'] =
            mismatch == 'cart' ? 'cart_02' : 'location_02';
        final client = _client(
          store,
          (_) async => http.Response(
            jsonEncode(responseCart),
            200,
            headers: {'etag': '"cart-2"'},
          ),
          customerTokenProvider: () async => 'customer-token',
        );

        final call = operation == 'redeem'
            ? client.loyalty.redeem(
                'location_01',
                'cart_01',
                const RedeemLoyaltyRequest(rewardId: 'reward_01'),
                options: const StorefrontRequestOptions(
                  idempotencyKey: stableKey,
                ),
              )
            : client.loyalty.cancelRedemption(
                'location_01',
                'cart_01',
                options: const StorefrontRequestOptions(
                  idempotencyKey: stableKey,
                ),
              );
        await expectLater(
          call,
          throwsA(
            isA<StorefrontDecodingException>().having(
              (error) => error.retryIdempotencyKey,
              'retryIdempotencyKey',
              stableKey,
            ),
          ),
        );
        expect((await store.read(_scope()))?.revision, 1);
        client.close();
      });
    }
  }

  test('ordering bootstrap requires matching ETag and body revisions',
      () async {
    final store = InMemoryStorefrontSessionStore();
    final client = _client(
      store,
      (_) async => http.Response(
        jsonEncode({
          'cart': _cartFixture(revision: 2),
          'cartAccessToken': 'cart-capability',
        }),
        201,
        headers: {'etag': '"cart-999"'},
      ),
    );

    await expectLater(
      client.orderingSessions.start(
        'location_01',
        StartOrderingSessionRequest.fresh(fulfillmentMethod: 'takeout'),
      ),
      throwsA(isA<StorefrontDecodingException>()),
    );
    expect(await store.read(_scope()), isNull);
    client.close();
  });

  for (final operation in ['ordering bootstrap', 'handoff exchange']) {
    test('$operation requires a valid cart ETag', () async {
      final store = InMemoryStorefrontSessionStore();
      final client = _client(
        store,
        (_) async => http.Response(
          jsonEncode({
            'cart': _cartFixture(revision: 2),
            'cartAccessToken': 'cart-capability',
            if (operation == 'handoff exchange')
              'merchantSlug': 'example-merchant',
          }),
          operation == 'ordering bootstrap' ? 201 : 200,
        ),
      );

      final call = operation == 'ordering bootstrap'
          ? client.orderingSessions.start(
              'location_01',
              StartOrderingSessionRequest.fresh(
                fulfillmentMethod: 'takeout',
              ),
            )
          : client.checkout.exchangeHandoff(
              'location_01',
              'cart_01',
              'handoff-capability',
              options: const StorefrontRequestOptions(
                idempotencyKey: 'same-handoff-exchange-0001',
              ),
            );
      await expectLater(
        call,
        throwsA(isA<StorefrontDecodingException>()),
      );
      expect(await store.read(_scope()), isNull);
      client.close();
    });
  }

  test('ordering resume rejects a different returned cart', () async {
    const stableKey = 'same-ordering-resume-0001';
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store);
    final returnedCart = _cartFixture(revision: 2)..['id'] = 'cart_02';
    final client = _client(
      store,
      (_) async => http.Response(
        jsonEncode({
          'cart': returnedCart,
          'cartAccessToken': 'different-cart-capability',
        }),
        201,
        headers: {'etag': '"cart-2"'},
      ),
    );

    await expectLater(
      client.orderingSessions.start(
        'location_01',
        StartOrderingSessionRequest(
          existingCartId: 'cart_01',
          fulfillmentMethod: 'takeout',
        ),
        options: const StorefrontRequestOptions(idempotencyKey: stableKey),
      ),
      throwsA(
        isA<StorefrontDecodingException>().having(
          (error) => error.retryIdempotencyKey,
          'retryIdempotencyKey',
          stableKey,
        ),
      ),
    );
    final stored = await store.read(_scope());
    expect(stored?.cartId, 'cart_01');
    expect(stored?.revision, 1);
    client.close();
  });

  test('handoff exchange requires matching ETag and body revisions', () async {
    const stableKey = 'same-handoff-exchange-0001';
    final store = InMemoryStorefrontSessionStore();
    final client = _client(
      store,
      (_) async => http.Response(
        jsonEncode({
          'cart': _cartFixture(revision: 2),
          'cartAccessToken': 'cart-capability',
          'merchantSlug': 'example-merchant',
        }),
        200,
        headers: {'etag': '"cart-999"'},
      ),
    );

    await expectLater(
      client.checkout.exchangeHandoff(
        'location_01',
        'cart_01',
        'handoff-capability',
        options: const StorefrontRequestOptions(
          idempotencyKey: stableKey,
        ),
      ),
      throwsA(
        isA<StorefrontDecodingException>().having(
          (error) => error.retryIdempotencyKey,
          'retryIdempotencyKey',
          stableKey,
        ),
      ),
    );
    expect(await store.read(_scope()), isNull);
    client.close();
  });

  test('rating requires an affirmative result before clearing capability',
      () async {
    const stableKey = 'same-rating-submit-0001';
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store);
    final client = _client(
      store,
      (_) async => http.Response(
        '{"success":false,"id":"rating_01"}',
        200,
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
        isA<StorefrontDecodingException>().having(
          (error) => error.retryIdempotencyKey,
          'retryIdempotencyKey',
          stableKey,
        ),
      ),
    );
    final stored = await store.read(_scope());
    expect(stored?.accessToken, 'cart-capability');
    expect(stored?.revision, 1);
    client.close();
  });
}

CraveStorefrontClient _client(
  StorefrontSessionStore store,
  Future<http.Response> Function(http.Request request) handler, {
  StorefrontCustomerTokenProvider? customerTokenProvider,
}) =>
    CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      sessionStore: store,
      customerTokenProvider: customerTokenProvider,
      httpClient: MockClient(handler),
    );

StorefrontSessionScope _scope() => StorefrontSessionScope(
      apiOrigin: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      locationId: 'location_01',
    );

Future<void> _seedSession(StorefrontSessionStore store) => store.write(
      StorefrontCartSession(
        scope: _scope(),
        cartId: 'cart_01',
        accessToken: 'cart-capability',
        revision: 1,
      ),
    );

Map<String, Object?> _cartFixture({required int revision}) {
  final decoded = jsonDecode(
    File('test/fixtures/cart.json').readAsStringSync(),
  ) as Map<String, Object?>;
  return <String, Object?>{...decoded, 'revision': revision};
}
