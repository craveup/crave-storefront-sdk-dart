import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/src/models/cart.dart';
import 'package:crave_storefront_sdk/src/models/catalog.dart';
import 'package:crave_storefront_sdk/src/models/common.dart';
import 'package:test/test.dart';

Map<String, Object?> fixture(String name) {
  final decoded = jsonDecode(
    File('test/fixtures/$name.json').readAsStringSync(),
  );
  return (decoded as Map<Object?, Object?>).cast<String, Object?>();
}

void main() {
  group('catalog models', () {
    test('decodes menus, fractional nutrition fields, and modifiers', () {
      final bundle = MenuBundle.fromJson(fixture('catalog'));
      final product = Product.fromJson(fixture('product'));

      expect(bundle.menus.single.categories.single.products.single.id,
          'product_01');
      expect(bundle.menus.single.imageUrl, isNull);
      expect(
        bundle.menus.single.categories.single.products.single.nutrition
            ?.calorieCount,
        12.5,
      );
      expect(product.modifiers.single.rule.minimum, 1);
      expect(product.modifiers.single.items.single.id, 'option_01');
      expect(product.locationId, 'location_01');
      expect(
        product.modifiers.single.imageUrl,
        'https://cdn.example.test/modifier.png',
      );
    });

    test('keeps a cart recommendation distinct from a full product', () {
      final recommendation = CartRecommendation.fromJson(<String, Object?>{
        'id': 'product_02',
        'name': 'Suggested Tea',
        'price': '4.50',
        'description': null,
        'availability': 'available',
        'images': <Object?>[],
        'modifierIds': <Object?>[],
      });

      expect(recommendation.id, 'product_02');
      expect(recommendation.description, isNull);
      expect(recommendation.modifierIds, isEmpty);
    });
  });

  group('cart models', () {
    test('decodes a cart and preserves response fulfilment spelling', () {
      final cart = StorefrontCart.fromJson(fixture('cart'));

      expect(cart.id, 'cart_01');
      expect(cart.fulfilmentMethod, 'takeout');
      expect(cart.revision, 3);
      expect(cart.items.single.itemUnavailableAction, 'future_action');
      expect(cart.deliveryInfo, isNull);
    });

    test('validates cart timestamps without echoing a rejected value', () {
      const rejected = 'secret-invalid-expiration';
      final json = fixture('cart')..['expiresAt'] = rejected;

      expect(
        () => StorefrontCart.fromJson(json),
        throwsA(
          isA<FormatException>()
              .having(
                (error) => error.message,
                'message',
                contains('cart.expiresAt'),
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains(rejected)),
              ),
        ),
      );
    });

    test('requires the server-owned cart item collection', () {
      for (final invalidItems in <Object?>[null, 'not-a-list']) {
        final json = fixture('cart')..['items'] = invalidItems;
        expect(
          () => StorefrontCart.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('cart.items'),
            ),
          ),
        );
      }
      final missing = fixture('cart')..remove('items');
      expect(
        () => StorefrontCart.fromJson(missing),
        throwsA(isA<FormatException>()),
      );
    });

    test('serializes cart updates with request fulfillment spelling', () {
      final request = UpdateCartRequest(
        fulfillmentMethod: FulfillmentMethod.delivery,
        pickupType: OrderTiming.scheduled,
        orderTime: '18:30',
        note: 'Leave at reception',
      );

      expect(request.toJson(), <String, Object?>{
        'fulfillmentMethod': 'delivery',
        'pickupType': 'LATER',
        'orderTime': '18:30',
        'note': 'Leave at reception',
      });
      expect(request.toJson(), isNot(contains('fulfilmentMethod')));
    });

    test('supports every cart fulfillment method wire value', () {
      expect(
        FulfillmentMethod.robotDelivery.wireValue,
        'robot_delivery',
      );
      expect(
        FulfillmentMethod.inCourseDelivery.wireValue,
        'in_course_delivery',
      );
    });

    test('allowlists add-item request fields recursively', () {
      final request = AddCartItemRequest(
        productId: 'product_01',
        quantity: 2,
        itemUnavailableAction: ItemUnavailableAction.removeItem,
        selections: <SelectedModifierGroup>[
          SelectedModifierGroup(
            groupId: 'modifier_01',
            selectedOptions: <SelectedModifierOption>[
              SelectedModifierOption(optionId: 'option_01', quantity: 1),
            ],
          ),
        ],
      );

      expect(request.toJson().keys, <String>[
        'productId',
        'quantity',
        'itemUnavailableAction',
        'selections',
      ]);
      expect(request.toJson(), isNot(contains('price')));
      expect(request.toJson(), isNot(contains('merchantId')));
    });

    test('rejects invalid item quantities before transport', () {
      expect(
        () => AddCartItemRequest(
          productId: 'product_01',
          quantity: 0,
          itemUnavailableAction: ItemUnavailableAction.removeItem,
          selections: const <SelectedModifierGroup>[],
        ),
        throwsArgumentError,
      );
    });

    test('uses a strict country enum for delivery address requests', () {
      final request = SetDeliveryRequest(
        address: DeliveryAddressRequest(
          street: '100 Example Street',
          city: 'Example City',
          state: 'NY',
          zipCode: '10001',
          country: SupportedCountry.unitedStates,
          lat: 40.7,
          lng: -74,
        ),
      );

      expect(request.toJson(), <String, Object?>{
        'street': '100 Example Street',
        'city': 'Example City',
        'state': 'NY',
        'zipCode': '10001',
        'country': 'United States',
        'lat': 40.7,
        'lng': -74,
      });
    });
  });
}
