import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';
import 'package:crave_storefront_sdk/src/http/transport.dart';
import 'package:crave_storefront_sdk/src/resources/checkout_loyalty_resources.dart'
    show
        createCheckoutClient,
        createLoyaltyClient,
        createRatingsClient,
        createReceiptsClient;
import 'package:crave_storefront_sdk/src/runtime/cart_session_runtime.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('payment intent uses cart capability, revision, and idempotency',
      () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store, revision: 3);
    late http.Request captured;
    final resources = _resources(
      store: store,
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"clientSecret":"fixture-client-secret"}',
          200,
          headers: {'etag': 'W/"cart-4"'},
        );
      }),
    );

    final result = await resources.checkout.createPaymentIntent(
      'location_01',
      'cart_01',
    );

    expect(result.clientSecret, 'fixture-client-secret');
    expect(captured.method, 'POST');
    expect(
      captured.url.path,
      '/api/v1/storefront/locations/location_01/carts/cart_01/payment-intent',
    );
    expect(captured.headers['x-cart-token'], 'cart-capability');
    expect(captured.headers['if-match'], '"cart-3"');
    expect(
      captured.headers['idempotency-key'],
      matches(RegExp(r'^[A-Za-z0-9._:-]{16,128}$')),
    );
    expect(jsonDecode(captured.body), isEmpty);
    expect((await store.read(_scope()))?.revision, 4);
    resources.transport.close();
  });

  for (final operation in [
    'payment intent',
    'loyalty redeem',
    'loyalty cancel'
  ]) {
    test('$operation conflict refreshes once without retrying the mutation',
        () async {
      final store = InMemoryStorefrontSessionStore();
      await _seedSession(store, revision: 4);
      var mutationCalls = 0;
      var getCalls = 0;
      final resources = _resources(
        store: store,
        customerTokenProvider: () async => 'customer-token',
        client: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.endsWith('/carts/cart_01')) {
            getCalls += 1;
            return http.Response(
              jsonEncode(_cartJson(revision: 9)),
              200,
              headers: {'etag': '"cart-9"'},
            );
          }
          mutationCalls += 1;
          return http.Response(
            jsonEncode({
              'code': 'CART_CONFLICT',
              'message': 'Sensitive server text.',
              'requestId': 'req_conflict',
            }),
            409,
          );
        }),
      );

      final call = switch (operation) {
        'payment intent' => resources.checkout.createPaymentIntent(
            'location_01',
            'cart_01',
          ),
        'loyalty redeem' => resources.loyalty.redeem(
            'location_01',
            'cart_01',
            const RedeemLoyaltyRequest(rewardId: 'reward_01'),
          ),
        _ => resources.loyalty.cancelRedemption(
            'location_01',
            'cart_01',
          ),
      };

      await expectLater(
        call,
        throwsA(
          isA<StorefrontApiException>().having(
            (error) => error.code,
            'code',
            'CART_CONFLICT',
          ),
        ),
      );
      expect(mutationCalls, 1);
      expect(getCalls, 1);
      expect((await store.read(_scope()))?.revision, 9);
      resources.transport.close();
    });
  }

  test('checkout handoff keeps capabilities isolated and captures exchange',
      () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store, revision: 2);
    final requests = <http.Request>[];
    var tokenCalls = 0;
    final resources = _resources(
      store: store,
      customerTokenProvider: () async {
        tokenCalls += 1;
        return 'customer-token';
      },
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/exchange')) {
          return http.Response(
            jsonEncode({
              'cart': _cartJson(revision: 7),
              'cartAccessToken': 'exchanged-cart-capability',
              'merchantSlug': 'example-merchant',
            }),
            200,
            headers: {'etag': 'W/"cart-7"'},
          );
        }
        return http.Response(
          jsonEncode({
            'checkoutUrl': 'https://checkout.example.test/session',
            'expiresAt': '2026-08-10T12:30:00.000Z',
          }),
          201,
        );
      }),
    );

    final handoff = await resources.checkout.prepareHandoff(
      'location_01',
      'cart_01',
    );
    final exchange = await resources.checkout.exchangeHandoff(
      'location_01',
      'cart_01',
      'checkout-handoff-capability',
      options: const StorefrontRequestOptions(
        idempotencyKey: 'checkout-exchange-0001',
      ),
    );

    expect(handoff.checkoutUrl.host, 'checkout.example.test');
    expect(exchange.cartAccessToken, 'exchanged-cart-capability');
    expect(tokenCalls, 0);
    expect(requests, hasLength(2));
    expect(requests[0].headers['x-cart-token'], 'cart-capability');
    expect(requests[0].headers, isNot(contains('authorization')));
    expect(requests[0].headers, isNot(contains('x-checkout-handoff')));
    expect(requests[0].headers['idempotency-key'], isNotNull);
    expect(requests[1].headers['x-checkout-handoff'],
        'checkout-handoff-capability');
    expect(requests[1].headers['idempotency-key'], 'checkout-exchange-0001');
    expect(requests[1].headers, isNot(contains('authorization')));
    expect(requests[1].headers, isNot(contains('x-cart-token')));
    final stored = await store.read(_scope());
    expect(stored?.cartId, 'cart_01');
    expect(stored?.accessToken, 'exchanged-cart-capability');
    expect(stored?.revision, 7);
    resources.transport.close();
  });

  test('checkout exchange rejects a response outside the configured scope',
      () async {
    final store = InMemoryStorefrontSessionStore();
    final resources = _resources(
      store: store,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'cart': _cartJson(revision: 7),
            'cartAccessToken': 'wrong-scope-capability',
            'merchantSlug': 'another-merchant',
          }),
          200,
          headers: {'etag': '"cart-7"'},
        ),
      ),
    );

    await expectLater(
      resources.checkout.exchangeHandoff(
        'location_01',
        'cart_01',
        'checkout-handoff-capability',
        options: const StorefrontRequestOptions(
          idempotencyKey: 'checkout-exchange-0001',
        ),
      ),
      throwsA(isA<StorefrontDecodingException>()),
    );

    expect(await store.read(_scope()), isNull);
    resources.transport.close();
  });

  test('checkout exchange rejects a different cart in the same tenant',
      () async {
    final store = InMemoryStorefrontSessionStore();
    final resources = _resources(
      store: store,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'cart': {
              ..._cartJson(revision: 7),
              'id': 'another_cart',
            },
            'cartAccessToken': 'wrong-cart-capability',
            'merchantSlug': 'example-merchant',
          }),
          200,
          headers: {'etag': '"cart-7"'},
        ),
      ),
    );

    await expectLater(
      resources.checkout.exchangeHandoff(
        'location_01',
        'cart_01',
        'checkout-handoff-capability',
        options: const StorefrontRequestOptions(
          idempotencyKey: 'checkout-exchange-0001',
        ),
      ),
      throwsA(isA<StorefrontDecodingException>()),
    );

    expect(await store.read(_scope()), isNull);
    resources.transport.close();
  });

  test('order result, rating, and receipt use only their allowed auth',
      () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store, revision: 2);
    final requests = <http.Request>[];
    var tokenCalls = 0;
    final resources = _resources(
      store: store,
      customerTokenProvider: () async {
        tokenCalls += 1;
        return 'customer-token';
      },
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/order-result')) {
          return http.Response('{"state":"payment_pending"}', 200);
        }
        if (request.url.path.endsWith('/rating')) {
          return http.Response('{"success":true,"id":"rating_01"}', 200);
        }
        return _fixtureResponse('customer_order.json');
      }),
    );

    final orderResult = await resources.checkout.getOrderResult(
      'location_01',
      'cart_01',
    );
    final rating = await resources.ratings.submit(
      'location_01',
      'cart_01',
      RatingRequest(rating: 5, comment: 'Great tea'),
    );
    expect(await store.read(_scope()), isNull);
    final guestReceipt = await resources.receipts.get(
      'receipt_01',
      receiptToken: 'receipt-capability',
    );
    final customerReceipt = await resources.receipts.get('receipt_02');

    expect(orderResult, isA<PaymentPendingOrderResult>());
    expect(rating.id, 'rating_01');
    expect(guestReceipt.id, 'order_01');
    expect(customerReceipt.id, 'order_01');
    expect(requests[0].headers['x-cart-token'], 'cart-capability');
    expect(requests[0].headers, isNot(contains('idempotency-key')));
    expect(requests[1].headers['x-cart-token'], 'cart-capability');
    expect(requests[1].headers['idempotency-key'], isNotNull);
    expect(requests[2].headers['x-receipt-token'], 'receipt-capability');
    expect(requests[2].headers, isNot(contains('authorization')));
    expect(requests[3].headers['authorization'], 'Bearer customer-token');
    expect(requests[3].headers, isNot(contains('x-receipt-token')));
    expect(tokenCalls, 1);
    resources.transport.close();
  });

  test('loyalty methods use customer auth and persist cart revisions',
      () async {
    final store = InMemoryStorefrontSessionStore();
    await _seedSession(store, revision: 3);
    final loyaltyFixture = _fixtureObject('loyalty.json');
    final requests = <http.Request>[];
    final resources = _resources(
      store: store,
      customerTokenProvider: () async => 'customer-token',
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/loyalty/quote')) {
          return http.Response(
            jsonEncode(loyaltyFixture['quote']),
            200,
            headers: {'etag': '"cart-4"'},
          );
        }
        if (path.endsWith('/loyalty/redeem')) {
          final revision = request.method == 'POST' ? 5 : 6;
          return http.Response(
            jsonEncode(_cartJson(revision: revision)),
            200,
            headers: {'etag': '"cart-$revision"'},
          );
        }
        if (path.endsWith('/loyalty/ledger')) {
          return http.Response(jsonEncode(loyaltyFixture['ledger']), 200);
        }
        if (path.endsWith('/loyalty/claims') && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'claimId': 'claim_01',
              'status': 'queued',
              'submittedAt': '2026-08-10T12:00:00.000Z',
            }),
            201,
          );
        }
        return http.Response(
          jsonEncode({
            'claims': [
              {
                'claimId': 'claim_01',
                'status': 'queued',
                'submittedAt': '2026-08-10T12:00:00.000Z',
                'reason': 'missing_points',
                'note': null,
                'points': null,
                'updatedAt': '2026-08-10T12:01:00.000Z',
              },
            ],
          }),
          200,
        );
      }),
    );

    final quote = await resources.loyalty.getQuote(
      'location_01',
      'cart_01',
    );
    final redeemed = await resources.loyalty.redeem(
      'location_01',
      'cart_01',
      const RedeemLoyaltyRequest(rewardId: 'reward_01'),
    );
    final cancelled = await resources.loyalty.cancelRedemption(
      'location_01',
      'cart_01',
    );
    final ledger = await resources.loyalty.getLedger(
      limit: 10,
      cursor: 'cursor-1',
    );
    final submission = await resources.loyalty.submitClaim(
      const SubmitLoyaltyClaimRequest(
        orderId: '0123456789abcdef01234567',
        reason: LoyaltyClaimReason.missingPoints,
        note: 'Missing points',
      ),
    );
    final claims = await resources.loyalty.listClaims();

    expect(quote.enabled, isTrue);
    expect(redeemed.revision, 5);
    expect(cancelled.revision, 6);
    expect(ledger.entries, hasLength(1));
    expect(submission.claimId, 'claim_01');
    expect(claims.claims, hasLength(1));
    expect((await store.read(_scope()))?.revision, 6);
    expect(requests, hasLength(6));
    for (final request in requests) {
      expect(request.headers['authorization'], 'Bearer customer-token');
      expect(request.headers, isNot(contains('x-cart-token')));
    }
    expect(requests[1].headers['if-match'], '"cart-4"');
    expect(requests[2].headers['if-match'], '"cart-5"');
    expect(requests[1].headers['idempotency-key'], isNotNull);
    expect(requests[2].headers['idempotency-key'], isNotNull);
    expect(requests[3].url.queryParameters, {
      'limit': '10',
      'cursor': 'cursor-1',
    });
    expect(requests[4].headers['idempotency-key'], isNotNull);
    expect(jsonDecode(requests[4].body), {
      'orderId': '0123456789abcdef01234567',
      'reason': 'missing_points',
      'note': 'Missing points',
    });
    resources.transport.close();
  });

  test('resource inputs are rejected locally before an HTTP request', () async {
    var requestCount = 0;
    final resources = _resources(
      client: MockClient((_) async {
        requestCount += 1;
        return http.Response('{}', 500);
      }),
    );

    await expectLater(
      resources.checkout.exchangeHandoff(
        'location_01',
        'cart_01',
        'handoff-capability',
        options: const StorefrontRequestOptions(),
      ),
      throwsA(isA<StorefrontConfigurationException>()),
    );
    await expectLater(
      resources.loyalty.getLedger(limit: 0),
      throwsA(isA<StorefrontConfigurationException>()),
    );
    await expectLater(
      resources.loyalty.getLedger(cursor: '   '),
      throwsA(isA<StorefrontConfigurationException>()),
    );
    await expectLater(
      resources.loyalty.getLedger(cursor: List.filled(513, 'x').join()),
      throwsA(isA<StorefrontConfigurationException>()),
    );
    await expectLater(
      resources.loyalty.redeem(
        'location_01',
        'cart_01',
        const RedeemLoyaltyRequest(rewardId: '   '),
      ),
      throwsA(isA<StorefrontConfigurationException>()),
    );
    await expectLater(
      resources.loyalty.submitClaim(
        const SubmitLoyaltyClaimRequest(
          orderId: 'not-an-order-id',
          reason: LoyaltyClaimReason.other,
        ),
      ),
      throwsA(isA<StorefrontConfigurationException>()),
    );
    await expectLater(
      resources.loyalty.submitClaim(
        const SubmitLoyaltyClaimRequest(
          orderId: '0123456789abcdef01234567',
          reason: LoyaltyClaimReason.other,
          note: '   ',
        ),
      ),
      throwsA(isA<StorefrontConfigurationException>()),
    );

    expect(requestCount, 0);
    resources.transport.close();
  });
}

({
  StorefrontTransport transport,
  CheckoutClient checkout,
  RatingsClient ratings,
  ReceiptsClient receipts,
  LoyaltyClient loyalty,
}) _resources({
  required http.Client client,
  InMemoryStorefrontSessionStore? store,
  StorefrontCustomerTokenProvider? customerTokenProvider,
}) {
  final transport = StorefrontTransport(
    baseUri: Uri.parse('https://api.example.test'),
    client: client,
    customerTokenProvider: customerTokenProvider,
  );
  final runtime = CartSessionRuntime(
    apiOrigin: transport.baseUri,
    merchantSlug: 'example-merchant',
    sessionStore: store ?? InMemoryStorefrontSessionStore(),
    idempotencyKeyGenerator: StorefrontIdempotencyKeyGenerator(),
  );
  return (
    transport: transport,
    checkout: createCheckoutClient(transport, runtime),
    ratings: createRatingsClient(transport, runtime),
    receipts: createReceiptsClient(transport),
    loyalty: createLoyaltyClient(transport, runtime),
  );
}

Map<String, Object?> _cartJson({required int revision}) => {
      ..._fixtureObject('cart.json'),
      'revision': revision,
    };

Map<String, Object?> _fixtureObject(String name) =>
    (jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map)
        .cast<String, Object?>();

http.Response _fixtureResponse(String name) => http.Response(
      File('test/fixtures/$name').readAsStringSync(),
      200,
      headers: const {'content-type': 'application/json'},
    );

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
