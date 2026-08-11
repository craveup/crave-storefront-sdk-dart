import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('public model decoders do not expose the internal JSON reader', () {
    final modelSources = Directory('lib/src/models')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(
      RegExp(r'\.fromReader\s*\(').allMatches(modelSources),
      isEmpty,
    );

    for (final model in _readerDecodedModels) {
      expect(
        modelSources,
        contains(RegExp('factory\\s+$model\\.fromJson\\s*\\(')),
        reason: '$model must expose only its Map-based decoder',
      );
    }
  });

  test('resource creation helpers stay outside the public entrypoint', () {
    final entrypoint = File('lib/crave_storefront_sdk.dart').readAsStringSync();

    for (final entry in _resourceExports.entries) {
      final directive = RegExp(
        "export '${RegExp.escape(entry.key)}'\\s+show\\s+([^;]+);",
        multiLine: true,
      ).firstMatch(entrypoint);
      expect(directive, isNotNull, reason: '${entry.key} must use show');
      final exportedNames =
          directive!.group(1)!.split(',').map((name) => name.trim()).toSet();
      expect(exportedNames, entry.value.toSet());

      final source = File('lib/${entry.key}').readAsStringSync();
      for (final className in entry.value) {
        expect(
          RegExp(
            '^  (?:const )?$className\\._\\s*\\(',
            multiLine: true,
          ).hasMatch(source),
          isTrue,
          reason: '$className must have a private package-owned constructor',
        );
        expect(
          RegExp(
            '^  (?:const )?$className(?:\\.[A-Za-z]\\w*)?\\s*\\(',
            multiLine: true,
          ).hasMatch(source),
          isFalse,
          reason: '$className must not expose its transport constructor',
        );
      }
    }
  });

  test('customer authentication requests do not duplicate tenant identity', () {
    final source = File('lib/src/models/customer.dart').readAsStringSync();
    final authRequests = source.substring(
          source.indexOf('final class CustomerLoginRequest'),
          source.indexOf('final class LoginChallenge'),
        ) +
        source.substring(
          source.indexOf('final class VerifyOtpRequest'),
          source.indexOf('final class AuthResult'),
        );

    expect(authRequests, isNot(contains('merchantSlug')));
  });
}

const _resourceExports = <String, List<String>>{
  'src/resources/catalog_resources.dart': <String>[
    'MerchantsClient',
    'LocationsClient',
    'MenusClient',
    'ProductsClient',
  ],
  'src/resources/checkout_loyalty_resources.dart': <String>[
    'CheckoutClient',
    'RatingsClient',
    'ReceiptsClient',
    'LoyaltyClient',
  ],
  'src/resources/customer_resources.dart': <String>['CustomersClient'],
  'src/resources/ordering_cart_resources.dart': <String>[
    'OrderingSessionsClient',
    'AnalyticsEventsClient',
    'CartsClient',
  ],
};

const _readerDecodedModels = <String>{
  'Address',
  'CartDeliveryInfo',
  'CartFees',
  'CartItem',
  'CartModifierGroup',
  'CartModifierItem',
  'CartProductSummary',
  'CartRecommendation',
  'CartRoomServiceInfo',
  'CartTableServiceInfo',
  'Coordinates',
  'DistanceLocation',
  'DistanceMeasurement',
  'LoyaltyClaim',
  'LoyaltyClaimSubmission',
  'LoyaltyLedgerBalance',
  'LoyaltyLedgerEntry',
  'LoyaltyPointBalance',
  'LoyaltyReward',
  'Menu',
  'MenuCategory',
  'MenuProduct',
  'MerchantFulfillmentMethods',
  'MerchantLocation',
  'ModifierChildLink',
  'ModifierGroup',
  'ModifierItem',
  'ModifierRule',
  'Nutrition',
  'OrderDay',
  'OrderingReadiness',
  'PublicOrderDeliveryInfo',
  'PublicOrderDetail',
  'PublicOrderItem',
  'PublicOrderModifier',
  'PublicOrderPayment',
  'PublicOrderPricing',
  'PublicOrderRoomServiceInfo',
  'PublicOrderSummary',
  'PublicOrderTableServiceInfo',
  'PublishedAddress',
  'StorefrontCart',
};
