import 'dart:async';
import 'dart:convert';

import 'package:crave_storefront_sdk/src/cancellation.dart';
import 'package:crave_storefront_sdk/src/errors.dart';
import 'package:crave_storefront_sdk/src/http/transport.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('StorefrontTransport configuration', () {
    test('requires an origin-only HTTPS URI outside loopback', () {
      for (final uri in [
        Uri.parse(''),
        Uri.parse('/relative'),
        Uri.parse('http://api.example.test'),
        Uri.parse('https://user:pass@api.example.test'),
        Uri.parse('https://api.example.test/path'),
        Uri.parse('https://api.example.test?token=secret'),
        Uri.parse('https://api.example.test#fragment'),
      ]) {
        expect(
          () => StorefrontTransport(baseUri: uri),
          throwsA(isA<StorefrontConfigurationException>()),
          reason: '$uri must be rejected',
        );
      }

      final local = StorefrontTransport(
        baseUri: Uri.parse('http://localhost:4708/'),
      );
      expect(local.baseUri, Uri.parse('http://localhost:4708'));
      local.close();
    });
  });

  group('StorefrontTransport requests', () {
    test('builds only fixed same-origin paths and safely encodes segments',
        () async {
      late http.Request captured;
      final transport = StorefrontTransport(
        baseUri: Uri.parse('https://api.example.test'),
        client: MockClient((request) async {
          captured = request;
          return http.Response('{"id":"ok"}', 200);
        }),
      );

      final result = await transport.send<Map<String, Object?>>(
        method: 'GET',
        pathSegments: const ['locations', 'id/with?delimiters'],
        routeTemplate: '/locations/:locationId',
        decoder: _mapDecoder,
      );

      expect(
        captured.url,
        Uri.parse(
          'https://api.example.test/api/v1/storefront/locations/id%2Fwith%3Fdelimiters',
        ),
      );
      expect(result.data, {'id': 'ok'});
      transport.close();
    });

    test('never asks for or attaches JWT on anonymous requests', () async {
      var tokenCalls = 0;
      late http.Request captured;
      final transport = StorefrontTransport(
        baseUri: Uri.parse('https://api.example.test'),
        customerTokenProvider: () async {
          tokenCalls += 1;
          return 'customer-secret';
        },
        client: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );

      await transport.send<Map<String, Object?>>(
        method: 'GET',
        pathSegments: const ['merchant', 'demo'],
        routeTemplate: '/merchant/:merchantSlug',
        authorization: StorefrontAuthorization.anonymous,
        decoder: _mapDecoder,
      );

      expect(tokenCalls, 0);
      expect(captured.headers, isNot(contains('authorization')));
      expect(captured.headers.keys, isNot(contains('x-api-key')));
      transport.close();
    });

    test('optional customer authorization works with and without a JWT',
        () async {
      final captured = <http.Request>[];
      final token = <String?>[null, 'customer-token'].iterator;
      final transport = StorefrontTransport(
        baseUri: Uri.parse('https://api.example.test'),
        customerTokenProvider: () async {
          token.moveNext();
          return token.current;
        },
        client: MockClient((request) async {
          captured.add(request);
          return http.Response('{}', 200);
        }),
      );

      for (var index = 0; index < 2; index += 1) {
        await transport.send<Map<String, Object?>>(
          method: 'POST',
          pathSegments: const ['locations', 'loc', 'ordering-sessions'],
          routeTemplate: '/locations/:locationId/ordering-sessions',
          authorization: StorefrontAuthorization.optionalCustomer,
          decoder: _mapDecoder,
        );
      }

      expect(captured[0].headers, isNot(contains('authorization')));
      expect(captured[1].headers['authorization'], 'Bearer customer-token');
      transport.close();
    });

    test('customer authorization fails before sending when no JWT is available',
        () async {
      var requestCount = 0;
      final transport = StorefrontTransport(
        baseUri: Uri.parse('https://api.example.test'),
        customerTokenProvider: () async => null,
        client: MockClient((_) async {
          requestCount += 1;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        transport.send<Map<String, Object?>>(
          method: 'GET',
          pathSegments: const ['customer'],
          routeTemplate: '/customer',
          authorization: StorefrontAuthorization.customer,
          decoder: _mapDecoder,
        ),
        throwsA(isA<StorefrontConfigurationException>()),
      );

      expect(requestCount, 0);
      transport.close();
    });

    test('timeout also bounds an unresponsive customer token provider',
        () async {
      final never = Completer<String?>();
      final transport = StorefrontTransport(
        baseUri: Uri.parse('https://api.example.test'),
        defaultTimeout: const Duration(milliseconds: 5),
        customerTokenProvider: () => never.future,
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      final pending = transport.send<Map<String, Object?>>(
        method: 'GET',
        pathSegments: const ['customer'],
        routeTemplate: '/customer',
        authorization: StorefrontAuthorization.customer,
        decoder: _mapDecoder,
      );
      final outcome = await Future.any<Object>([
        pending
            .then<Object>((value) => value)
            .catchError((Object error) => error),
        Future<Object>.delayed(
          const Duration(milliseconds: 100),
          () => 'provider-was-not-bounded',
        ),
      ]);

      expect(outcome, isA<StorefrontTimeoutException>());
      transport.close();
    });

    test('redacts customer token provider failures', () async {
      const secret = 'provider-secret-customer-token';
      final transport = StorefrontTransport(
        baseUri: Uri.parse('https://api.example.test'),
        customerTokenProvider: () async => throw StateError(secret),
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        transport.send<Map<String, Object?>>(
          method: 'GET',
          pathSegments: const ['customer'],
          routeTemplate: '/customer',
          authorization: StorefrontAuthorization.customer,
          decoder: _mapDecoder,
        ),
        throwsA(
          isA<StorefrontNetworkException>().having(
            (error) => error.toString(),
            'safe string',
            isNot(contains(secret)),
          ),
        ),
      );
      transport.close();
    });

    test('keeps each capability in its dedicated header', () async {
      final captured = <http.Request>[];
      final transport = StorefrontTransport(
        baseUri: Uri.parse('https://api.example.test'),
        customerTokenProvider: () async => 'customer-token',
        client: MockClient((request) async {
          captured.add(request);
          return http.Response('{}', 200);
        }),
      );

      await transport.send<Map<String, Object?>>(
        method: 'GET',
        pathSegments: const ['customer'],
        routeTemplate: '/customer',
        authorization: StorefrontAuthorization.customer,
        decoder: _mapDecoder,
      );
      await transport.send<Map<String, Object?>>(
        method: 'GET',
        pathSegments: const ['locations', 'loc', 'carts', 'cart'],
        routeTemplate: '/locations/:locationId/carts/:cartId',
        authorization: StorefrontAuthorization.cart,
        cartToken: 'cart-token',
        decoder: _mapDecoder,
      );
      await transport.send<Map<String, Object?>>(
        method: 'POST',
        pathSegments: const [
          'locations',
          'loc',
          'carts',
          'cart',
          'checkout-handoffs',
          'exchange',
        ],
        routeTemplate:
            '/locations/:locationId/carts/:cartId/checkout-handoffs/exchange',
        authorization: StorefrontAuthorization.checkoutHandoff,
        checkoutHandoffToken: 'handoff-token',
        decoder: _mapDecoder,
      );
      await transport.send<Map<String, Object?>>(
        method: 'GET',
        pathSegments: const ['receipts', 'receipt'],
        routeTemplate: '/receipts/:receiptId',
        authorization: StorefrontAuthorization.receiptOrCustomer,
        receiptToken: 'receipt-token',
        decoder: _mapDecoder,
      );

      expect(captured[0].headers['authorization'], 'Bearer customer-token');
      expect(captured[1].headers['x-cart-token'], 'cart-token');
      expect(captured[1].headers, isNot(contains('authorization')));
      expect(captured[2].headers['x-checkout-handoff'], 'handoff-token');
      expect(captured[2].headers, isNot(contains('authorization')));
      expect(captured[3].headers['x-receipt-token'], 'receipt-token');
      expect(captured[3].headers, isNot(contains('authorization')));
      transport.close();
    });

    test('sends JSON, query, idempotency, and revision headers', () async {
      late http.Request captured;
      final transport = StorefrontTransport(
        baseUri: Uri.parse('https://api.example.test'),
        client: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200, headers: {'etag': 'W/"cart-8"'});
        }),
      );

      final result = await transport.send<Map<String, Object?>>(
        method: 'PATCH',
        pathSegments: const ['locations', 'loc', 'carts', 'cart'],
        routeTemplate: '/locations/:locationId/carts/:cartId',
        query: const {'menuOnly': true, 'missing': null},
        body: const {'fulfillmentMethod': 'takeout'},
        cartToken: 'cart-token',
        authorization: StorefrontAuthorization.cart,
        idempotencyKey: 'stable_key-123456',
        revision: const StorefrontRevision.cart(7),
        decoder: _mapDecoder,
      );

      expect(captured.url.queryParameters, {'menuOnly': 'true'});
      expect(
          captured.headers['content-type'], 'application/json; charset=utf-8');
      expect(captured.headers['idempotency-key'], 'stable_key-123456');
      expect(captured.headers['if-match'], '"cart-7"');
      expect(jsonDecode(captured.body), {'fulfillmentMethod': 'takeout'});
      expect(result.etag, 'W/"cart-8"');
      transport.close();
    });

    test('does not follow redirects', () async {
      late http.Request captured;
      final transport = StorefrontTransport(
        baseUri: Uri.parse('https://api.example.test'),
        customerTokenProvider: () async => 'customer-token',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            '',
            302,
            headers: {'location': 'https://attacker.example/collect'},
          );
        }),
      );

      await expectLater(
        transport.send<Map<String, Object?>>(
          method: 'GET',
          pathSegments: const ['customer'],
          routeTemplate: '/customer',
          authorization: StorefrontAuthorization.customer,
          decoder: _mapDecoder,
        ),
        throwsA(
          isA<StorefrontApiException>()
              .having((error) => error.statusCode, 'statusCode', 302)
              .having(
                (error) => error.toString(),
                'safe string',
                isNot(contains('attacker.example')),
              ),
        ),
      );
      expect(captured.followRedirects, isFalse);
      transport.close();
    });

    test('maps the canonical API error without retaining secrets', () async {
      const secret = 'otp_123456_customer@example.test';
      final transport = StorefrontTransport(
        baseUri: Uri.parse('https://api.example.test'),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 'VALIDATION_ERROR',
              'message': 'The request is invalid.',
              'requestId': 'req_123',
              'details': {'token': secret, 'fields': <Object?>[]},
            }),
            400,
          ),
        ),
      );

      await expectLater(
        transport.send<Map<String, Object?>>(
          method: 'POST',
          pathSegments: const ['customer', 'auth', 'verify-otp'],
          routeTemplate: '/customer/auth/verify-otp',
          body: const {'otp': secret},
          decoder: _mapDecoder,
        ),
        throwsA(
          isA<StorefrontApiException>()
              .having((error) => error.code, 'code', 'VALIDATION_ERROR')
              .having((error) => error.requestId, 'requestId', 'req_123')
              .having(
                (error) => '$error ${error.details}',
                'redacted representation',
                isNot(contains(secret)),
              ),
        ),
      );
      transport.close();
    });

    test('distinguishes timeout and caller cancellation', () async {
      final never = Completer<http.Response>();
      final transport = StorefrontTransport(
        baseUri: Uri.parse('https://api.example.test'),
        defaultTimeout: const Duration(milliseconds: 5),
        client: MockClient((_) => never.future),
      );

      await expectLater(
        transport.send<Map<String, Object?>>(
          method: 'GET',
          pathSegments: const ['merchant', 'demo'],
          routeTemplate: '/merchant/:merchantSlug',
          decoder: _mapDecoder,
        ),
        throwsA(isA<StorefrontTimeoutException>()),
      );

      final token = StorefrontCancellationToken();
      final pending = transport.send<Map<String, Object?>>(
        method: 'GET',
        pathSegments: const ['merchant', 'demo'],
        routeTemplate: '/merchant/:merchantSlug',
        timeout: const Duration(seconds: 5),
        cancellationToken: token,
        decoder: _mapDecoder,
      );
      token.cancel();
      await expectLater(
        pending,
        throwsA(isA<StorefrontRequestCancelledException>()),
      );
      transport.close();
    });

    test('maps malformed success JSON to a safe decoding error', () async {
      final transport = StorefrontTransport(
        baseUri: Uri.parse('https://api.example.test'),
        client: MockClient((_) async => http.Response('private-value', 200)),
      );

      await expectLater(
        transport.send<Map<String, Object?>>(
          method: 'GET',
          pathSegments: const ['merchant', 'demo'],
          routeTemplate: '/merchant/:merchantSlug',
          decoder: _mapDecoder,
        ),
        throwsA(
          isA<StorefrontDecodingException>().having(
            (error) => error.toString(),
            'safe string',
            isNot(contains('private-value')),
          ),
        ),
      );
      transport.close();
    });
  });
}

Map<String, Object?> _mapDecoder(Object? value) {
  return (value as Map).cast<String, Object?>();
}
