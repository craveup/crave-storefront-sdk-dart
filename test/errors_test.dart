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
        retryIdempotencyKey: 'token-like-private-value',
      ),
      const StorefrontTimeoutException(
        method: 'GET',
        routeTemplate: '/customer/orders/:orderId',
        timeout: Duration(seconds: 10),
        retryIdempotencyKey: 'token-like-private-value',
      ),
      const StorefrontRequestCancelledException(
        method: 'GET',
        routeTemplate: '/customer',
        retryIdempotencyKey: 'token-like-private-value',
      ),
      const StorefrontNetworkException(
        method: 'GET',
        routeTemplate: '/merchant/:merchantSlug',
        retryIdempotencyKey: 'token-like-private-value',
      ),
      const StorefrontSessionException(
        method: 'POST',
        routeTemplate: '/locations/:locationId/carts/:cartId',
        operationMayHaveSucceeded: true,
        retryIdempotencyKey: 'token-like-private-value',
      ),
      const StorefrontDecodingException(
        method: 'GET',
        routeTemplate: '/merchant/:merchantSlug',
        retryIdempotencyKey: 'token-like-private-value',
      ),
    ];

    for (final error in errors) {
      expect(error.toString(), isNot(contains('https://')));
      expect(error.toString(), isNot(contains('token')));
    }
  });
}
