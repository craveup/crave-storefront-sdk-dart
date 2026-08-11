import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/src/models/cart.dart';
import 'package:crave_storefront_sdk/src/models/location.dart';
import 'package:crave_storefront_sdk/src/models/merchant.dart';
import 'package:test/test.dart';

Map<String, Object?> fixture(String name) {
  final decoded = jsonDecode(
    File('test/fixtures/$name.json').readAsStringSync(),
  );
  return (decoded as Map<Object?, Object?>).cast<String, Object?>();
}

void main() {
  group('merchant and location responses', () {
    test('decodes additive fields and nullable presentation data', () {
      final merchant = Merchant.fromJson(fixture('merchant'));

      expect(merchant.id, 'merchant_01');
      expect(merchant.bio, isNull);
      expect(merchant.locations, hasLength(1));
      expect(merchant.locations.single.lat, 40.7128);
      expect(merchant.locations.single.lng, isNull);
      expect(merchant.locations.single.methods.delivery, isTrue);
    });

    test('decodes the published location address', () {
      final location = StorefrontLocation.fromJson(fixture('location'));

      expect(location.id, 'location_01');
      expect(location.restaurantBio, isNull);
      expect(location.address?.city, 'Example City');
      expect(location.address?.lat, 40.7128);
    });

    test('accepts a partial published address with nullable coordinates', () {
      final location = StorefrontLocation.fromJson(<String, Object?>{
        'id': 'location_01',
        'restaurantSlug': 'example-tea-downtown',
        'restaurantDisplayName': 'Example Tea Downtown',
        'addressData': <String, Object?>{
          'lat': null,
          'lng': -74.006,
        },
        'addressString': 'Downtown',
      });

      expect(location.address?.street, isNull);
      expect(location.address?.city, isNull);
      expect(location.address?.lat, isNull);
      expect(location.address?.lng, -74.006);
    });

    test('keeps an unknown response distance unit without crashing', () {
      final result = DistanceResult.fromJson(<String, Object?>{
        'locationId': 'location_01',
        'location': <String, Object?>{
          'id': 'location_01',
          'restaurantDisplayName': 'Example Tea Downtown',
          'addressString': '100 Example Street',
          'coordinates': <String, Object?>{'lat': 40.7, 'lng': -74.0},
        },
        'distance': <String, Object?>{
          'value': 2.5,
          'unit': 'leagues',
          'miles': 1.2,
          'kilometers': 2.0,
        },
        'addedLater': true,
      });

      expect(result.location.id, 'location_01');
      expect(result.distance.unit, 'leagues');
      expect(result.distance.miles, 1.2);
    });

    test('request validation errors do not retain rejected coordinates', () {
      const rejected = 98765.4321;
      Object? failure;

      try {
        DistanceRequest(lat: rejected, lng: -74);
      } on Object catch (error) {
        failure = error;
      }

      expect(failure, isA<ArgumentError>());
      expect(failure.toString(), isNot(contains('$rejected')));
    });

    test('decodes both ordering readiness response variants', () {
      final unavailable = OrderingReadiness.fromJson(<String, Object?>{
        'ready': false,
        'fulfillmentMethod': 'delivery',
        'reason': 'Delivery is currently unavailable.',
      });
      final ready = OrderingReadiness.fromJson(<String, Object?>{
        'ready': true,
        'fulfillmentMethod': 'takeout',
        'pickupType': 'ASAP',
        'orderDate': '2026-08-11',
        'orderTime': '12:15',
        'estimatedReadyTime': '2026-08-11T07:15:00Z',
      });

      expect(unavailable, isA<OrderingUnavailable>());
      expect(unavailable.fulfillmentMethod, FulfillmentMethod.delivery);
      expect((unavailable as OrderingUnavailable).reason,
          'Delivery is currently unavailable.');
      expect(ready, isA<OrderingReady>());
      expect(ready.fulfillmentMethod, FulfillmentMethod.takeout);
      expect((ready as OrderingReady).pickupType, OrderTiming.asap);
      expect(ready.orderDate, '2026-08-11');
      expect(ready.orderTime, '12:15');
      expect(ready.estimatedReadyTime, '2026-08-11T07:15:00Z');
    });

    test('rejects unknown ordering readiness enum values safely', () {
      const rejected = 'secret_new_fulfillment';

      expect(
        () => OrderingReadiness.fromJson(<String, Object?>{
          'ready': false,
          'fulfillmentMethod': rejected,
          'reason': 'Unavailable.',
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            isNot(contains(rejected)),
          ),
        ),
      );
    });
  });
}
