import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';
import 'package:test/test.dart';

void main() {
  test('typed client surface covers every manifest SDK operation exactly once',
      () {
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.test'),
      merchantSlug: 'example-merchant',
    );
    final implemented = <String, Object>{
      'locations.get': client.locations.get,
      'locations.calculateDistance': client.locations.calculateDistance,
      'locations.listTimeIntervals': client.locations.listTimeIntervals,
      'locations.getGratuity': client.locations.getGratuity,
      'checkout.createPaymentIntent': client.checkout.createPaymentIntent,
      'checkout.getOrderResult': client.checkout.getOrderResult,
      'checkout.prepareHandoff': client.checkout.prepareHandoff,
      'checkout.exchangeHandoff': client.checkout.exchangeHandoff,
      'ratings.submit': client.ratings.submit,
      'menus.getForLocation': client.menus.getForLocation,
      'products.getForLocation': client.products.getForLocation,
      'merchants.get': client.merchants.get,
      'orderingSessions.start': client.orderingSessions.start,
      'analyticsEvents.submit': client.analyticsEvents.submit,
      'carts.get': client.carts.get,
      'carts.listRecommendedProducts': client.carts.listRecommendedProducts,
      'carts.update': client.carts.update,
      'carts.delete': client.carts.delete,
      'carts.validateForCheckout': client.carts.validateForCheckout,
      'carts.updateGratuity': client.carts.updateGratuity,
      'carts.setDelivery': client.carts.setDelivery,
      'carts.setTable': client.carts.setTable,
      'carts.setRoom': client.carts.setRoom,
      'carts.updateOrderTime': client.carts.updateOrderTime,
      'carts.applyDiscount': client.carts.applyDiscount,
      'carts.removeDiscount': client.carts.removeDiscount,
      'carts.claim': client.carts.claim,
      'carts.addItem': client.carts.addItem,
      'carts.updateItemQuantity': client.carts.updateItemQuantity,
      'carts.removeItem': client.carts.removeItem,
      'loyalty.getQuote': client.loyalty.getQuote,
      'loyalty.redeem': client.loyalty.redeem,
      'loyalty.cancelRedemption': client.loyalty.cancelRedemption,
      'loyalty.getLedger': client.loyalty.getLedger,
      'loyalty.submitClaim': client.loyalty.submitClaim,
      'loyalty.listClaims': client.loyalty.listClaims,
      'customers.requestLogin': client.customers.requestLogin,
      'customers.verifyOtp': client.customers.verifyOtp,
      'customers.getProfile': client.customers.getProfile,
      'customers.listOrders': client.customers.listOrders,
      'customers.getOrder': client.customers.getOrder,
      'customers.listAddresses': client.customers.listAddresses,
      'customers.createAddress': client.customers.createAddress,
      'customers.updateAddress': client.customers.updateAddress,
      'customers.deleteAddress': client.customers.deleteAddress,
      'customers.listSavedPayments': client.customers.listSavedPayments,
      'customers.deleteSavedPayment': client.customers.deleteSavedPayment,
      'customers.logout': client.customers.logout,
      'receipts.get': client.receipts.get,
    };
    final manifest = (jsonDecode(
      File('tool/storefront_operations.json').readAsStringSync(),
    ) as Map<String, Object?>)['operations']! as List<Object?>;
    final declared = manifest
        .map((entry) => (entry! as Map<String, Object?>)['sdkMethod'])
        .whereType<String>()
        .toSet();

    expect(implemented.keys.toSet(), declared);
    expect(implemented, hasLength(49));
    client.close();
  });
}
