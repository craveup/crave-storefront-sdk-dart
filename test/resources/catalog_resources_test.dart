import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('public resources reject path traversal identifiers locally', () async {
    var requestCount = 0;
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      httpClient: MockClient((_) async {
        requestCount += 1;
        return http.Response('{}', 200);
      }),
      sessionStore: InMemoryStorefrontSessionStore(),
    );

    await expectLater(
      client.locations.get('..'),
      throwsA(isA<StorefrontConfigurationException>()),
    );
    expect(requestCount, 0);
    client.close();
  });

  test('catalog resources use exact anonymous Storefront routes', () async {
    final requests = <http.Request>[];
    var tokenCalls = 0;
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      customerTokenProvider: () async {
        tokenCalls += 1;
        return 'customer-token';
      },
      httpClient: MockClient((request) async {
        requests.add(request);
        return switch (request.url.path) {
          '/api/v1/storefront/merchant/example-merchant' =>
            _fixtureResponse('merchant.json'),
          '/api/v1/storefront/locations/location%2Fone' =>
            _fixtureResponse('location.json'),
          '/api/v1/storefront/locations/location_01/distance' => http.Response(
              jsonEncode({
                'locationId': 'location_01',
                'location': {
                  'id': 'location_01',
                  'restaurantDisplayName': 'Example Tea',
                  'addressString': '100 Example Street',
                  'coordinates': {'lat': 40.0, 'lng': -74.0},
                },
                'distance': {
                  'value': 1.2,
                  'unit': 'miles',
                  'miles': 1.2,
                  'kilometers': 1.93,
                },
              }),
              200,
            ),
          '/api/v1/storefront/locations/location_01/time-intervals' =>
            http.Response(
              jsonEncode({
                'orderDays': [
                  {
                    'value': '2026-08-10',
                    'label': 'Today',
                    'intervals': ['12:00', '12:15'],
                  },
                ],
                'scheduleAllowed': true,
                'requireScheduledOrders': false,
              }),
              200,
            ),
          '/api/v1/storefront/locations/location_01/ordering-readiness' =>
            http.Response(
              jsonEncode({
                'ready': true,
                'fulfillmentMethod': 'delivery',
                'pickupType': 'LATER',
                'orderDate': '2026-08-11',
                'orderTime': '18:30',
                'estimatedReadyTime': '2026-08-11T22:30:00Z',
              }),
              200,
            ),
          '/api/v1/storefront/locations/location_01/gratuity' => http.Response(
              jsonEncode({
                'enabled': true,
                'shouldAllowCustomTip': true,
                'tipPercentage': ['15', '20'],
                'defaultTipPercentage': '20',
                'description': null,
              }),
              200,
            ),
          '/api/v1/storefront/locations/location_01/menus' =>
            _fixtureResponse('catalog.json'),
          '/api/v1/storefront/locations/location_01/products/product%2Fone' =>
            _fixtureResponse('product.json'),
          _ => http.Response('{}', 404),
        };
      }),
    );

    final merchant = await client.merchants.get();
    final location = await client.locations.get('location/one');
    final distance = await client.locations.calculateDistance(
      'location_01',
      DistanceRequest(lat: 40, lng: -74),
    );
    final times = await client.locations.listTimeIntervals('location_01');
    final readiness = await client.locations.getOrderingReadiness(
      'location_01',
      fulfillmentMethod: FulfillmentMethod.delivery,
    );
    final gratuity = await client.locations.getGratuity('location_01');
    final menus = await client.menus.getForLocation(
      'location_01',
      menuOnly: true,
    );
    final product = await client.products.getForLocation(
      'location_01',
      'product/one',
    );

    expect(merchant.id, 'merchant_01');
    expect(location.id, 'location_01');
    expect(distance.distance.miles, 1.2);
    expect(times.orderDays, hasLength(1));
    expect(readiness, isA<OrderingReady>());
    expect(readiness.fulfillmentMethod, FulfillmentMethod.delivery);
    expect(gratuity.enabled, isTrue);
    expect(menus.menus, hasLength(1));
    expect(product.id, 'product_01');
    expect(tokenCalls, 0);
    expect(requests, hasLength(8));
    for (final request in requests) {
      expect(request.headers, isNot(contains('authorization')));
      expect(request.headers, isNot(contains('x-api-key')));
    }
    expect(
      requests[4].url.queryParameters,
      {'fulfillmentMethod': 'delivery'},
    );
    expect(
      requests[6].url.queryParameters,
      {'menuOnly': 'true'},
    );
    client.close();
  });

  test('menu requests reject incomplete scheduling inputs locally', () async {
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );

    await expectLater(
      client.menus.getForLocation('location_01', orderDate: '2026-08-10'),
      throwsA(isA<StorefrontConfigurationException>()),
    );
    client.close();
  });
}

http.Response _fixtureResponse(String name) => http.Response(
      File('test/fixtures/$name').readAsStringSync(),
      200,
      headers: const {'content-type': 'application/json'},
    );
