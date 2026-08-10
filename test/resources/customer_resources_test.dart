import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';
import 'package:crave_storefront_sdk/src/http/transport.dart';
import 'package:crave_storefront_sdk/src/resources/customer_resources.dart'
    show createCustomersClient;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('customer login and OTP verification stay anonymous', () async {
    final requests = <http.Request>[];
    var tokenCalls = 0;
    final customers = _customers(
      tokenProvider: () async {
        tokenCalls += 1;
        return 'customer-token';
      },
      handler: (request) async {
        requests.add(request);
        return request.url.path.endsWith('/login')
            ? http.Response(
                jsonEncode({'methodId': 'method_01', 'delivery': 'email'}),
                200,
              )
            : http.Response(jsonEncode({'token': 'signed-session-jwt'}), 200);
      },
    );

    final challenge = await customers.requestLogin(
      const CustomerLoginRequest(
        identifierString: 'developer@example.test',
      ),
    );
    final auth = await customers.verifyOtp(
      VerifyOtpRequest(
        identifierString: 'developer@example.test',
        methodId: challenge.methodId,
        otp: '123456',
      ),
    );

    expect(challenge.delivery, 'email');
    expect(auth.token, 'signed-session-jwt');
    expect(tokenCalls, 0);
    expect(
      requests.map((request) => '${request.method} ${request.url.path}'),
      [
        'POST /api/v1/storefront/customer/auth/login',
        'POST /api/v1/storefront/customer/auth/verify-otp',
      ],
    );
    expect(
      jsonDecode(requests.first.body),
      {
        'merchantSlug': 'example-merchant',
        'identifierString': 'developer@example.test',
      },
    );
    for (final request in requests) {
      expect(request.headers, isNot(contains('authorization')));
      expect(request.headers, isNot(contains('x-api-key')));
    }
  });

  test('customer reads use JWT auth, exact paths, and bounded pagination',
      () async {
    final requests = <http.Request>[];
    final order = _orderJson();
    final customers = _customers(
      handler: (request) async {
        requests.add(request);
        return switch (request.url.path) {
          '/api/v1/storefront/customer' => http.Response(
              jsonEncode({
                'id': 'customer_01',
                'profilePicture': '',
                'customerEmail': 'developer@example.test',
                'customerName': 'Example',
                'lastName': 'Developer',
                'phoneNumber': null,
              }),
              200,
            ),
          '/api/v1/storefront/customer/orders' => http.Response(
              jsonEncode({
                'items': [order],
                'nextCursor': 'next-orders',
              }),
              200,
            ),
          '/api/v1/storefront/customer/orders/order%2Fone' =>
            http.Response(jsonEncode(order), 200),
          '/api/v1/storefront/customer/addresses' => http.Response(
              jsonEncode({
                'items': [_addressJson()],
                'nextCursor': 'next-addresses',
              }),
              200,
            ),
          _ => http.Response('{}', 404),
        };
      },
    );

    final profile = await customers.getProfile();
    final orders = await customers.listOrders(limit: 2, cursor: 'order-page');
    final orderDetail = await customers.getOrder('order/one');
    final addresses = await customers.listAddresses(
      limit: 3,
      cursor: 'address-page',
    );

    expect(profile.id, 'customer_01');
    expect(orders.items.single.id, 'order_01');
    expect(orderDetail.pricing.total, '5.50');
    expect(addresses.items.single.revision, 3);
    expect(
      requests[1].url.queryParameters,
      {'limit': '2', 'cursor': 'order-page'},
    );
    expect(
      requests[3].url.queryParameters,
      {'limit': '3', 'cursor': 'address-page'},
    );
    for (final request in requests) {
      expect(request.headers['authorization'], 'Bearer customer-token');
      expect(request.headers, isNot(contains('x-api-key')));
    }
  });

  test('address mutations centralize idempotency and address revision',
      () async {
    final requests = <http.Request>[];
    final customers = _customers(
      handler: (request) async {
        requests.add(request);
        if (request.method == 'DELETE') {
          return http.Response(
            jsonEncode({'success': true, 'addressId': 'address_01'}),
            200,
          );
        }
        if (request.method == 'PATCH') {
          return http.Response(
            jsonEncode(_addressJson(revision: 4)),
            200,
            headers: {'etag': '"address-4"'},
          );
        }
        return http.Response(jsonEncode(_addressJson()), 200);
      },
    );

    final created = await customers.createAddress(
      CreateCustomerAddressRequest(
        fullAddress: '100 Example Street',
        line1: '100 Example Street',
        lat: 40.7,
        lng: -74,
      ),
    );
    final updated = await customers.updateAddress(
      'address/one',
      UpdateCustomerAddressRequest(line2: 'Suite 2'),
      options: const StorefrontRequestOptions(
        idempotencyKey: 'address_update_key_0001',
        revision: 3,
      ),
    );
    final deleted = await customers.deleteAddress(
      'address_01',
      options: const StorefrontRequestOptions(
        idempotencyKey: 'address_delete_key_0001',
      ),
    );

    expect(created.addressId, 'address_01');
    expect(updated.revision, 4);
    expect(deleted.success, isTrue);
    expect(
      requests.map((request) => '${request.method} ${request.url.path}'),
      [
        'POST /api/v1/storefront/customer/addresses',
        'PATCH /api/v1/storefront/customer/addresses/address%2Fone',
        'DELETE /api/v1/storefront/customer/addresses/address_01',
      ],
    );
    expect(
      requests.first.headers['idempotency-key'],
      matches(RegExp(r'^sf_[A-Za-z0-9_-]{24}$')),
    );
    expect(
      requests[1].headers['idempotency-key'],
      'address_update_key_0001',
    );
    expect(requests[1].headers['if-match'], '"address-3"');
    expect(
      requests[2].headers['idempotency-key'],
      'address_delete_key_0001',
    );
    expect(jsonDecode(requests[1].body), {'line2': 'Suite 2'});
    for (final request in requests) {
      expect(request.headers['authorization'], 'Bearer customer-token');
    }
  });

  for (final etag in <String?>[null, '"address-99"']) {
    test(
        'address update rejects ${etag == null ? 'missing' : 'mismatched'} ETag',
        () async {
      final customers = _customers(
        handler: (_) async => http.Response(
          jsonEncode(_addressJson(revision: 4)),
          200,
          headers: {if (etag != null) 'etag': etag},
        ),
      );

      await expectLater(
        customers.updateAddress(
          'address_01',
          UpdateCustomerAddressRequest(line2: 'Suite 2'),
          options: const StorefrontRequestOptions(
            idempotencyKey: 'address_update_key_0001',
            revision: 3,
          ),
        ),
        throwsA(isA<StorefrontDecodingException>()),
      );
    });
  }

  test('saved payments and logout use customer auth without mutation headers',
      () async {
    final requests = <http.Request>[];
    final customers = _customers(
      handler: (request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 'pm_01',
                'brand': 'visa',
                'displayBrand': 'Visa',
                'expMonth': 12,
                'expYear': 2030,
                'last4': '4242',
              },
            ]),
            200,
          );
        }
        return http.Response(jsonEncode({'success': true}), 200);
      },
    );

    final payments = await customers.listSavedPayments();
    final removed = await customers.deleteSavedPayment('pm/one');
    final loggedOut = await customers.logout();

    expect(payments.single.last4, '4242');
    expect(
      () => payments[0] = payments[0],
      throwsUnsupportedError,
    );
    expect(removed.success, isTrue);
    expect(loggedOut.success, isTrue);
    expect(
      requests.map((request) => '${request.method} ${request.url.path}'),
      [
        'GET /api/v1/storefront/customer/saved-payments',
        'DELETE /api/v1/storefront/customer/saved-payments/pm%2Fone',
        'DELETE /api/v1/storefront/customer/logout',
      ],
    );
    for (final request in requests) {
      expect(request.headers['authorization'], 'Bearer customer-token');
      expect(request.headers, isNot(contains('idempotency-key')));
      expect(request.headers, isNot(contains('if-match')));
    }
  });

  test('customer resources reject unsafe local inputs before transport',
      () async {
    var requestCalls = 0;
    final customers = _customers(
      handler: (_) async {
        requestCalls += 1;
        return http.Response('{}', 200);
      },
    );

    await expectLater(
      customers.listOrders(limit: 0),
      throwsA(isA<StorefrontConfigurationException>()),
    );
    await expectLater(
      customers.listAddresses(cursor: 'x' * 513),
      throwsA(isA<StorefrontConfigurationException>()),
    );
    await expectLater(
      customers.updateAddress(
        'address_01',
        UpdateCustomerAddressRequest(line1: 'Updated'),
      ),
      throwsA(isA<StorefrontConfigurationException>()),
    );
    expect(requestCalls, 0);
  });
}

CustomersClient _customers({
  required Future<http.Response> Function(http.Request request) handler,
  StorefrontCustomerTokenProvider? tokenProvider,
}) {
  final transport = StorefrontTransport(
    baseUri: Uri.parse('https://api.example.test'),
    customerTokenProvider: tokenProvider ?? () async => 'customer-token',
    client: MockClient(handler),
  );
  return createCustomersClient(
    transport,
    'example-merchant',
    StorefrontIdempotencyKeyGenerator(),
  );
}

Map<String, Object?> _addressJson({int revision = 3}) => <String, Object?>{
      'addressId': 'address_01',
      'fullAddress': '100 Example Street',
      'line1': '100 Example Street',
      'line2': '',
      'line3': '',
      'lat': 40.7,
      'lng': -74,
      'revision': revision,
      'createdAt': '2026-08-10T12:00:00.000Z',
    };

Map<String, Object?> _orderJson() =>
    (jsonDecode(File('test/fixtures/customer_order.json').readAsStringSync())
            as Map)
        .cast<String, Object?>();
