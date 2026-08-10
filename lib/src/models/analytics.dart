import '../json/json_reader.dart';

/// Analytics event accepted by the public Storefront endpoint.
enum AnalyticsEventType {
  /// Storefront or QR scan.
  scan('SCAN'),

  /// Cart viewed.
  cartView('CART_VIEW'),

  /// Checkout viewed.
  checkoutView('CHECKOUT_VIEW');

  const AnalyticsEventType(this.wireValue);

  /// Value sent to the Storefront API.
  final String wireValue;
}

/// A best-effort Storefront analytics event.
final class AnalyticsEventRequest {
  /// Creates an immutable analytics event.
  AnalyticsEventRequest({
    required this.cartId,
    required this.eventType,
    Map<String, Object?>? metadata,
  }) : metadata = metadata == null
            ? null
            : freezeJsonMap(metadata, context: 'analyticsEvent.metadata');

  /// Cart referenced by this event.
  final String cartId;

  /// Event type accepted by the public endpoint.
  final AnalyticsEventType eventType;

  /// Caller-defined, non-sensitive metadata.
  final Map<String, Object?>? metadata;

  /// Serializes only fields accepted by the analytics endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'cartId': cartId,
        'eventType': eventType.wireValue,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Server acknowledgement for an analytics event.
final class AnalyticsEventResult {
  /// Creates an immutable analytics acknowledgement.
  const AnalyticsEventResult({required this.status});

  /// Decodes an analytics response.
  factory AnalyticsEventResult.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'analyticsEvent');
    return AnalyticsEventResult(status: reader.string('status'));
  }

  /// Acknowledgement wire value, including future values.
  final String status;
}
