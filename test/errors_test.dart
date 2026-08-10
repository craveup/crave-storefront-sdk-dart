import 'package:crave_storefront_sdk/src/errors.dart';
import 'package:test/test.dart';

void main() {
  test('all public exception strings use templates rather than resolved URLs',
      () {
    final errors = <StorefrontException>[
      const StorefrontApiException(
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: 'Authentication is required.',
        requestId: 'req_1',
        method: 'GET',
        routeTemplate: '/customer',
      ),
      const StorefrontTimeoutException(
        method: 'GET',
        routeTemplate: '/customer/orders/:orderId',
        timeout: Duration(seconds: 10),
      ),
      const StorefrontRequestCancelledException(
        method: 'GET',
        routeTemplate: '/customer',
      ),
      const StorefrontNetworkException(
        method: 'GET',
        routeTemplate: '/merchant/:merchantSlug',
      ),
      const StorefrontDecodingException(
        method: 'GET',
        routeTemplate: '/merchant/:merchantSlug',
      ),
    ];

    for (final error in errors) {
      expect(error.toString(), isNot(contains('https://')));
      expect(error.toString(), isNot(contains('token')));
    }
  });
}
