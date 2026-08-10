import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/src/models/checkout.dart';
import 'package:test/test.dart';

Map<String, Object?> orderFixture() {
  final decoded = jsonDecode(
    File('test/fixtures/customer_order.json').readAsStringSync(),
  );
  return (decoded as Map<Object?, Object?>).cast<String, Object?>();
}

Map<String, Object?> cartFixture() {
  final decoded = jsonDecode(
    File('test/fixtures/cart.json').readAsStringSync(),
  );
  return (decoded as Map<Object?, Object?>).cast<String, Object?>();
}

void main() {
  group('checkout', () {
    test('decodes handoff, exchange, and payment-intent responses', () {
      final handoff = CheckoutHandoff.fromJson(<String, Object?>{
        'checkoutUrl': 'https://checkout.example.test/session',
        'expiresAt': '2026-08-10T12:30:00.000Z',
      });
      final exchange = CheckoutExchangeResult.fromJson(<String, Object?>{
        'cart': cartFixture(),
        'cartAccessToken': 'fixture-cart-capability',
        'merchantSlug': 'example-tea',
      });
      final payment = PaymentIntent.fromJson(<String, Object?>{
        'clientSecret': 'fixture-client-secret',
      });

      expect(handoff.checkoutUrl.host, 'checkout.example.test');
      expect(exchange.cart.id, 'cart_01');
      expect(exchange.merchantSlug, 'example-tea');
      expect(payment.clientSecret, 'fixture-client-secret');
    });

    test('rejects an insecure remote checkout URL', () {
      expect(
        () => CheckoutHandoff.fromJson(const <String, Object?>{
          'checkoutUrl': 'http://checkout.example.test/session',
          'expiresAt': '2026-08-10T12:30:00.000Z',
        }),
        throwsFormatException,
      );
    });

    test('decodes every known order-result state', () {
      expect(
        OrderResult.fromJson(<String, Object?>{'state': 'payment_pending'}),
        isA<PaymentPendingOrderResult>(),
      );
      expect(
        OrderResult.fromJson(<String, Object?>{'state': 'order_pending'}),
        isA<OrderPendingOrderResult>(),
      );
      final completed = OrderResult.fromJson(<String, Object?>{
        'state': 'completed',
        'order': orderFixture(),
      });
      expect(completed, isA<CompletedOrderResult>());
      expect((completed as CompletedOrderResult).order.id, 'order_01');
      final failed = OrderResult.fromJson(<String, Object?>{
        'state': 'failed',
        'code': 'PAYMENT_FAILED',
      });
      expect((failed as FailedOrderResult).code, 'PAYMENT_FAILED');
    });

    test('preserves an unknown future order-result state', () {
      final result = OrderResult.fromJson(<String, Object?>{
        'state': 'awaiting_vendor',
        'futureField': true,
      });

      expect(result, isA<UnknownOrderResult>());
      expect(result.state, 'awaiting_vendor');
    });
  });

  group('ratings', () {
    test('allowlists rating request and decodes result', () {
      final request = RatingRequest(rating: 5, comment: 'Great tea');
      final result = RatingResult.fromJson(<String, Object?>{
        'success': true,
        'id': 'rating_01',
      });

      expect(request.toJson(), <String, Object?>{
        'rating': 5,
        'comment': 'Great tea',
      });
      expect(result.id, 'rating_01');
      expect(() => RatingRequest(rating: 6), throwsArgumentError);
    });
  });
}
