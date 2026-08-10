import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/src/models/analytics.dart';
import 'package:crave_storefront_sdk/src/models/ordering.dart';
import 'package:test/test.dart';

Map<String, Object?> cartFixture() {
  final decoded = jsonDecode(
    File('test/fixtures/cart.json').readAsStringSync(),
  );
  return (decoded as Map<Object?, Object?>).cast<String, Object?>();
}

void main() {
  test('ordering-session request allowlists typed fields', () {
    final request = StartOrderingSessionRequest(
      fulfillmentMethod: 'table-17',
      existingCartId: 'cart_01',
      marketplaceId: 'flutter',
      channel: OrderChannel.app,
      metadata: <String, Object?>{'campaign': 'example'},
      returnUrl: Uri.parse('example-app://checkout'),
    );

    expect(request.toJson(), <String, Object?>{
      'fulfillmentMethod': 'table-17',
      'existingCartId': 'cart_01',
      'marketplaceId': 'flutter',
      'channel': 'app',
      'metadata': <String, Object?>{'campaign': 'example'},
      'returnUrl': 'example-app://checkout',
    });
    expect(request.toJson(), isNot(contains('customerId')));
    expect(request.toJson(), isNot(contains('cartAccessToken')));
  });

  test('ordering-session request rejects reserved return URL schemes', () {
    expect(
      () => StartOrderingSessionRequest(
        fulfillmentMethod: 'takeout',
        returnUrl: Uri.parse('javascript:private-value'),
      ),
      throwsArgumentError,
    );
  });

  test('ordering-session request keeps return URLs out of metadata', () {
    expect(
      () => StartOrderingSessionRequest(
        fulfillmentMethod: 'takeout',
        metadata: const <String, Object?>{
          'returnUrl': 'https://private.example.test',
        },
      ),
      throwsArgumentError,
    );
  });

  test('request metadata rejects nested sensitive keys without echoing them',
      () {
    const privateKey = 'auth_token';
    const privateValue = 'private-value';

    for (final createRequest in <Object Function()>[
      () => StartOrderingSessionRequest(
            fulfillmentMethod: 'takeout',
            metadata: const <String, Object?>{
              'nested': <String, Object?>{privateKey: privateValue},
            },
          ),
      () => AnalyticsEventRequest(
            cartId: 'cart_01',
            eventType: AnalyticsEventType.scan,
            metadata: const <String, Object?>{
              'nested': <String, Object?>{privateKey: privateValue},
            },
          ),
    ]) {
      Object? failure;
      try {
        createRequest();
      } on Object catch (error) {
        failure = error;
      }
      expect(failure, isA<ArgumentError>());
      expect('$failure', isNot(contains(privateKey)));
      expect('$failure', isNot(contains(privateValue)));
    }
  });

  test('ordering and analytics payloads reject more than 8 KiB', () {
    final oversized = List<String>.filled(8192, 'x').join();

    expect(
      () => StartOrderingSessionRequest(
        fulfillmentMethod: 'takeout',
        metadata: <String, Object?>{'campaign': oversized},
      ),
      throwsArgumentError,
    );
    expect(
      () => AnalyticsEventRequest(
        cartId: 'cart_01',
        eventType: AnalyticsEventType.scan,
        metadata: <String, Object?>{'surface': oversized},
      ),
      throwsArgumentError,
    );
  });

  test('ordering-session result decodes the cart and capability', () {
    final result = StartOrderingSessionResult.fromJson(<String, Object?>{
      'cart': cartFixture(),
      'cartAccessToken': 'fixture-capability',
      'futureServerField': true,
    });

    expect(result.cart.id, 'cart_01');
    expect(result.cartAccessToken, 'fixture-capability');
  });

  test(
      'ordering-session request supports explicit fresh cart and safe URL checks',
      () {
    final fresh = StartOrderingSessionRequest.fresh(
      fulfillmentMethod: 'pickup',
    );

    expect(fresh.toJson(), <String, Object?>{
      'fulfillmentMethod': 'pickup',
      'existingCartId': null,
    });
    expect(
      () => StartOrderingSessionRequest(
        fulfillmentMethod: 'takeout',
        returnUrl: Uri.parse('/relative'),
      ),
      throwsArgumentError,
    );
  });

  test('ordering fulfillment identifiers are trimmed and bounded', () {
    final request = StartOrderingSessionRequest(
      fulfillmentMethod: '  room-1204  ',
    );

    expect(request.fulfillmentMethod, 'room-1204');
    expect(request.toJson()['fulfillmentMethod'], 'room-1204');
    expect(
      () => StartOrderingSessionRequest(fulfillmentMethod: '   '),
      throwsArgumentError,
    );
    expect(
      () => StartOrderingSessionRequest(
        fulfillmentMethod: List<String>.filled(65, 'x').join(),
      ),
      throwsArgumentError,
    );
  });

  test('invalid metadata values fail without exposing keys or values', () {
    const privateKey = 'customer_email_alice@example.com';
    final privateValue = Object();

    for (final createRequest in <Object Function()>[
      () => StartOrderingSessionRequest(
            fulfillmentMethod: 'takeout',
            metadata: <String, Object?>{privateKey: privateValue},
          ),
      () => AnalyticsEventRequest(
            cartId: 'cart_01',
            eventType: AnalyticsEventType.scan,
            metadata: <String, Object?>{privateKey: privateValue},
          ),
    ]) {
      Object? failure;
      try {
        createRequest();
      } on Object catch (error) {
        failure = error;
      }
      expect(failure, isA<ArgumentError>());
      expect('$failure', isNot(contains(privateKey)));
      expect('$failure', isNot(contains('$privateValue')));
    }
  });

  test('analytics request uses only server-accepted event values', () {
    final request = AnalyticsEventRequest(
      cartId: 'cart_01',
      eventType: AnalyticsEventType.cartView,
      metadata: <String, Object?>{'surface': 'cart'},
    );

    expect(request.toJson(), <String, Object?>{
      'cartId': 'cart_01',
      'eventType': 'CART_VIEW',
      'metadata': <String, Object?>{'surface': 'cart'},
    });
    expect(
      AnalyticsEventResult.fromJson(<String, Object?>{'status': 'accepted'})
          .status,
      'accepted',
    );
  });
}
