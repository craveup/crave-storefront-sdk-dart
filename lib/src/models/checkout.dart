import '../json/json_reader.dart';
import 'cart.dart';
import 'customer.dart';

/// One-time checkout handoff prepared for a hosted checkout flow.
final class CheckoutHandoff {
  /// Creates an immutable checkout handoff.
  const CheckoutHandoff({
    required this.checkoutUrl,
    required this.expiresAt,
  });

  /// Decodes a checkout-handoff response.
  factory CheckoutHandoff.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'checkoutHandoff');
    final checkoutUrl = Uri.tryParse(reader.string('checkoutUrl'));
    if (checkoutUrl == null ||
        !checkoutUrl.isAbsolute ||
        checkoutUrl.host.isEmpty) {
      throw const FormatException(
        'Invalid JSON at checkoutHandoff.checkoutUrl: expected an absolute URL.',
      );
    }
    return CheckoutHandoff(
      checkoutUrl: checkoutUrl,
      expiresAt: reader.timestamp('expiresAt'),
    );
  }

  /// Hosted checkout URL. Treat it as a call-scoped capability.
  final Uri checkoutUrl;

  /// ISO-8601 expiration timestamp wire value.
  final String expiresAt;
}

/// Result of exchanging a checkout handoff for an app-owned cart session.
final class CheckoutExchangeResult {
  /// Creates an immutable checkout exchange result.
  const CheckoutExchangeResult({
    required this.cart,
    required this.cartAccessToken,
    required this.merchantSlug,
  });

  /// Decodes a checkout-exchange response.
  factory CheckoutExchangeResult.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'checkoutExchange');
    return CheckoutExchangeResult(
      cart: StorefrontCart.fromReader(reader.object('cart')),
      cartAccessToken: reader.string('cartAccessToken'),
      merchantSlug: reader.string('merchantSlug'),
    );
  }

  /// Exchanged cart.
  final StorefrontCart cart;

  /// Guest cart capability issued for the app session.
  final String cartAccessToken;

  /// Canonical merchant slug used to scope the session.
  final String merchantSlug;
}

/// Payment intent data needed by a caller-owned Stripe integration.
final class PaymentIntent {
  /// Creates an immutable payment-intent result.
  const PaymentIntent({required this.clientSecret});

  /// Decodes a payment-intent response.
  factory PaymentIntent.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'paymentIntent');
    return PaymentIntent(clientSecret: reader.string('clientSecret'));
  }

  /// Stripe client secret. Never log or persist this value unnecessarily.
  final String clientSecret;
}

/// Checkout polling result.
sealed class OrderResult {
  const OrderResult(this.state);

  /// Decodes the current checkout state.
  factory OrderResult.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'orderResult');
    final state = reader.string('state');
    return switch (state) {
      'payment_pending' => const PaymentPendingOrderResult(),
      'order_pending' => const OrderPendingOrderResult(),
      'completed' => CompletedOrderResult(
          PublicOrderDetail.fromReader(reader.object('order')),
        ),
      'failed' => FailedOrderResult(reader.string('code')),
      _ => UnknownOrderResult(state),
    };
  }

  /// Checkout-state wire value, including future states.
  final String state;
}

/// Payment has not completed yet.
final class PaymentPendingOrderResult extends OrderResult {
  /// Creates the payment-pending result.
  const PaymentPendingOrderResult() : super('payment_pending');
}

/// Payment succeeded but the order is still being created.
final class OrderPendingOrderResult extends OrderResult {
  /// Creates the order-pending result.
  const OrderPendingOrderResult() : super('order_pending');
}

/// Order creation completed.
final class CompletedOrderResult extends OrderResult {
  /// Creates a completed result for [order].
  const CompletedOrderResult(this.order) : super('completed');

  /// Completed public order details.
  final PublicOrderDetail order;
}

/// Checkout failed with a safe server code.
final class FailedOrderResult extends OrderResult {
  /// Creates a failed result with [code].
  const FailedOrderResult(this.code) : super('failed');

  /// Safe failure code returned by the Storefront API.
  final String code;
}

/// A checkout state added by a newer API version.
final class UnknownOrderResult extends OrderResult {
  /// Creates a result that preserves an unknown [state].
  const UnknownOrderResult(super.state);
}

/// Customer rating submitted after checkout.
final class RatingRequest {
  /// Creates a validated rating request.
  RatingRequest({required this.rating, this.comment}) {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('rating must be between 1 and 5.');
    }
    if (comment != null && comment!.length > 500) {
      throw ArgumentError('comment must contain at most 500 characters.');
    }
  }

  /// Integer rating from 1 through 5.
  final int rating;

  /// Optional customer comment.
  final String? comment;

  /// Serializes only fields accepted by the rating endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'rating': rating,
        if (comment != null) 'comment': comment,
      };
}

/// Result of submitting a customer rating.
final class RatingResult {
  /// Creates an immutable rating result.
  const RatingResult({required this.success, required this.id});

  /// Decodes a rating response.
  factory RatingResult.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'rating');
    return RatingResult(
      success: reader.boolean('success'),
      id: reader.string('id'),
    );
  }

  /// Whether the rating was accepted.
  final bool success;

  /// Stable rating identifier.
  final String id;
}
