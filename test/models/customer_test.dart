import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/src/models/common.dart';
import 'package:crave_storefront_sdk/src/models/customer.dart';
import 'package:test/test.dart';

Map<String, Object?> fixture(String name) {
  final decoded = jsonDecode(
    File('test/fixtures/$name.json').readAsStringSync(),
  );
  return (decoded as Map<Object?, Object?>).cast<String, Object?>();
}

void main() {
  group('customer identity', () {
    test('serializes login and OTP requests with an explicit allowlist', () {
      final login = CustomerLoginRequest(
        merchantSlug: 'example-tea',
        identifierString: 'developer@example.test',
      );
      final otp = VerifyOtpRequest(
        merchantSlug: 'example-tea',
        identifierString: 'developer@example.test',
        methodId: 'method_01',
        otp: '123456',
        customerName: 'Example Customer',
      );

      expect(login.toJson().keys, <String>['merchantSlug', 'identifierString']);
      expect(otp.toJson().keys, <String>[
        'merchantSlug',
        'identifierString',
        'methodId',
        'otp',
        'customerName',
      ]);
      expect(otp.toJson(), isNot(contains('customerId')));
    });

    test('decodes extensible auth responses and nullable profile fields', () {
      final challenge = LoginChallenge.fromJson(<String, Object?>{
        'methodId': 'method_01',
        'delivery': 'push',
      });
      final auth =
          AuthResult.fromJson(<String, Object?>{'token': 'fixture-jwt'});
      final customer = StorefrontCustomer.fromJson(<String, Object?>{
        'id': 'customer_01',
        'profilePicture': '',
        'customerEmail': null,
        'customerName': 'Example Customer',
        'lastName': '',
        'phoneNumber': null,
      });

      expect(challenge.delivery, 'push');
      expect(auth.token, 'fixture-jwt');
      expect(customer.customerEmail, isNull);
    });
  });

  group('addresses and pagination', () {
    test('allowlists create and partial update address fields', () {
      final create = CreateCustomerAddressRequest(
        fullAddress: '100 Example Street',
        line1: '100 Example Street',
        lat: 40.7,
        lng: -74,
      );
      final update = UpdateCustomerAddressRequest(line2: 'Suite 2');

      expect(create.toJson().keys, <String>[
        'fullAddress',
        'line1',
        'lat',
        'lng',
      ]);
      expect(update.toJson(), <String, Object?>{'line2': 'Suite 2'});
      expect(UpdateCustomerAddressRequest.new, throwsArgumentError);
    });

    test('decodes a typed customer-address page', () {
      final page = CursorPage<CustomerAddress>.fromJson(
        <String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'addressId': 'address_01',
              'fullAddress': '100 Example Street',
              'line1': '100 Example Street',
              'line2': '',
              'line3': '',
              'lat': 40.7,
              'lng': -74,
              'revision': 2,
              'createdAt': '2026-08-10T12:00:00.000Z',
            },
          ],
          'nextCursor': null,
        },
        CustomerAddress.fromJson,
      );

      expect(page.items.single.revision, 2);
      expect(page.nextCursor, isNull);
    });
  });

  group('orders and saved payments', () {
    test('decodes a detailed order and preserves future statuses', () {
      final order = PublicOrderDetail.fromJson(fixture('customer_order'));

      expect(order.id, 'order_01');
      expect(order.status, 'future_status');
      expect(order.pricing.total, '5.50');
      expect(order.payment?.cardLast4, '4242');
      expect(order.updatedAt, isNull);
    });

    test('decodes the API saved-payment projection and ignores additions', () {
      final payment = SavedPaymentMethod.fromJson(<String, Object?>{
        'id': 'pm_fixture',
        'brand': 'visa',
        'displayBrand': 'Visa',
        'expMonth': 12,
        'expYear': 2030,
        'last4': '4242',
        'future': 'ignored',
      });

      expect(payment.last4, '4242');
      expect(payment.expMonth, 12);
      expect(payment.displayBrand, 'Visa');
    });
  });
}
