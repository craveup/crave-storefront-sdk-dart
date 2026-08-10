import 'package:crave_storefront_sdk/src/models/models.dart';
import 'package:test/test.dart';

void main() {
  test('model barrel exposes every operation family', () {
    final values = <Object>[
      Merchant.fromJson(<String, Object?>{
        'id': 'merchant_01',
        'name': 'Example Tea',
        'country': 'US',
        'currency': 'usd',
        'locations': <Object?>[],
      }),
      DistanceRequest(lat: 0, lng: 0),
      CartRecommendation(
        id: 'product_01',
        name: 'Tea',
        price: '1.00',
        images: <String>[],
        modifierIds: <String>[],
      ),
      const SuccessResult(success: true),
      const PaymentPendingOrderResult(),
      LoyaltyClaims(claims: <LoyaltyClaim>[]),
    ];

    expect(values, hasLength(6));
  });
}
