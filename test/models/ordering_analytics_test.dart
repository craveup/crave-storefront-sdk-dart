import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/src/models/analytics.dart';
import 'package:crave_storefront_sdk/src/models/cart.dart';
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
      fulfillmentMethod: FulfillmentMethod.takeout,
      existingCartId: 'cart_01',
      marketplaceId: 'flutter',
      channel: OrderChannel.app,
      metadata: <String, Object?>{'campaign': 'example'},
      returnUrl: Uri.parse('example-app://checkout'),
    );

    expect(request.toJson(), <String, Object?>{
      'fulfillmentMethod': 'takeout',
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
        fulfillmentMethod: FulfillmentMethod.takeout,
        returnUrl: Uri.parse('javascript:private-value'),
      ),
      throwsArgumentError,
    );
  });

  test('ordering-session request keeps return URLs out of metadata', () {
    expect(
      () => StartOrderingSessionRequest(
        fulfillmentMethod: FulfillmentMethod.takeout,
        metadata: const <String, Object?>{
          'returnUrl': 'https://private.example.test',
        },
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
      fulfillmentMethod: FulfillmentMethod.takeout,
    );

    expect(fresh.toJson(), <String, Object?>{
      'fulfillmentMethod': 'takeout',
      'existingCartId': null,
    });
    expect(
      () => StartOrderingSessionRequest(
        fulfillmentMethod: FulfillmentMethod.takeout,
        returnUrl: Uri.parse('/relative'),
      ),
      throwsArgumentError,
    );
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
