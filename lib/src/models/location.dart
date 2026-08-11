import '../json/json_reader.dart';
import 'cart.dart';

/// Current ordering availability for one fulfillment method.
sealed class OrderingReadiness {
  const OrderingReadiness({required this.fulfillmentMethod});

  /// Decodes the discriminated ordering-readiness response.
  factory OrderingReadiness.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'orderingReadiness');
    final fulfillmentMethod = _decodeFulfillmentMethod(
      reader.string('fulfillmentMethod'),
    );
    if (!reader.boolean('ready')) {
      return OrderingUnavailable(
        fulfillmentMethod: fulfillmentMethod,
        reason: reader.string('reason'),
      );
    }
    return OrderingReady(
      fulfillmentMethod: fulfillmentMethod,
      pickupType: _decodeOrderTiming(reader.string('pickupType')),
      orderDate: reader.string('orderDate'),
      orderTime: reader.string('orderTime'),
      estimatedReadyTime: reader.nullableTimestamp('estimatedReadyTime'),
    );
  }

  /// Whether ordering can start now with the returned order timing.
  bool get ready;

  /// Fulfillment method evaluated by the Storefront API.
  final FulfillmentMethod fulfillmentMethod;
}

/// Ordering is unavailable for the requested fulfillment method.
final class OrderingUnavailable extends OrderingReadiness {
  /// Creates an immutable unavailable response.
  const OrderingUnavailable({
    required super.fulfillmentMethod,
    required this.reason,
  });

  @override
  bool get ready => false;

  /// Customer-safe reason returned by the Storefront API.
  final String reason;
}

/// Ordering is available with an authoritative date and time.
final class OrderingReady extends OrderingReadiness {
  /// Creates an immutable ready response.
  const OrderingReady({
    required super.fulfillmentMethod,
    required this.pickupType,
    required this.orderDate,
    required this.orderTime,
    this.estimatedReadyTime,
  });

  @override
  bool get ready => true;

  /// Whether the order is immediate or scheduled.
  final OrderTiming pickupType;

  /// Restaurant-local order date wire value.
  final String orderDate;

  /// Restaurant-local order time wire value.
  final String orderTime;

  /// Optional ISO-8601 estimated-ready timestamp.
  final String? estimatedReadyTime;
}

FulfillmentMethod _decodeFulfillmentMethod(String value) => switch (value) {
      'takeout' => FulfillmentMethod.takeout,
      'table_side' => FulfillmentMethod.tableSide,
      'room_service' => FulfillmentMethod.roomService,
      'delivery' => FulfillmentMethod.delivery,
      _ => throw const FormatException(
          'Invalid JSON at orderingReadiness.fulfillmentMethod: '
          'expected a supported fulfillment method.',
        ),
    };

OrderTiming _decodeOrderTiming(String value) => switch (value) {
      'ASAP' => OrderTiming.asap,
      'LATER' => OrderTiming.scheduled,
      _ => throw const FormatException(
          'Invalid JSON at orderingReadiness.pickupType: '
          'expected ASAP or LATER.',
        ),
    };

/// Partially configured postal data published for a Storefront location.
final class PublishedAddress {
  /// Creates immutable published address data.
  const PublishedAddress({
    this.street,
    this.streetOptional,
    this.city,
    this.state,
    this.zipCode,
    this.country,
    this.lat,
    this.lng,
  });

  /// Decodes optional published address fields.
  factory PublishedAddress.fromJson(Map<String, Object?> json) =>
      PublishedAddress._fromReader(
        JsonReader.fromObject(json, context: 'publishedAddress'),
      );

  factory PublishedAddress._fromReader(JsonReader reader) => PublishedAddress(
        street: reader.nullableString('street'),
        streetOptional: reader.nullableString('streetOptional'),
        city: reader.nullableString('city'),
        state: reader.nullableString('state'),
        zipCode: reader.nullableString('zipCode'),
        country: reader.nullableString('country'),
        lat: reader.nullableNumber('lat'),
        lng: reader.nullableNumber('lng'),
      );

  /// Primary street line, when published.
  final String? street;

  /// Secondary street line, when published.
  final String? streetOptional;

  /// City name, when published.
  final String? city;

  /// State, province, or region, when published.
  final String? state;

  /// Postal code, when published.
  final String? zipCode;

  /// Country name or code, when published.
  final String? country;

  /// Latitude, when published.
  final double? lat;

  /// Longitude, when published.
  final double? lng;
}

/// A published Storefront location.
final class StorefrontLocation {
  /// Creates an immutable location.
  const StorefrontLocation({
    required this.id,
    required this.restaurantSlug,
    required this.restaurantDisplayName,
    required this.addressString,
    this.restaurantBio,
    this.coverPhoto,
    this.restaurantLogo,
    this.address,
  });

  /// Decodes a location response and ignores unknown additive fields.
  factory StorefrontLocation.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'location');
    final addressReader = reader.nullableObject('addressData');
    return StorefrontLocation(
      id: reader.string('id'),
      restaurantSlug: reader.string('restaurantSlug'),
      restaurantDisplayName: reader.string('restaurantDisplayName'),
      restaurantBio: reader.nullableString('restaurantBio'),
      coverPhoto: reader.nullableString('coverPhoto'),
      restaurantLogo: reader.nullableString('restaurantLogo'),
      address: addressReader == null
          ? null
          : PublishedAddress._fromReader(addressReader),
      addressString: reader.string('addressString'),
    );
  }

  /// Stable location identifier.
  final String id;

  /// Public location slug.
  final String restaurantSlug;

  /// Customer-facing restaurant name.
  final String restaurantDisplayName;

  /// Optional restaurant biography.
  final String? restaurantBio;

  /// Optional cover-image URL.
  final String? coverPhoto;

  /// Optional restaurant-logo URL.
  final String? restaurantLogo;

  /// Structured address, when present.
  final PublishedAddress? address;

  /// Customer-facing address.
  final String addressString;
}

/// Distance unit accepted by a distance request.
enum DistanceUnit {
  /// Statute miles.
  miles('miles'),

  /// Kilometers.
  kilometers('kilometers');

  const DistanceUnit(this.wireValue);

  /// Value sent to the Storefront API.
  final String wireValue;
}

/// Coordinates used to calculate distance to a location.
final class DistanceRequest {
  /// Creates a validated distance request.
  DistanceRequest({
    required this.lat,
    required this.lng,
    this.unit = DistanceUnit.miles,
  }) {
    if (!lat.isFinite || lat < -90 || lat > 90) {
      throw ArgumentError('lat must be between -90 and 90.');
    }
    if (!lng.isFinite || lng < -180 || lng > 180) {
      throw ArgumentError('lng must be between -180 and 180.');
    }
  }

  /// Latitude.
  final double lat;

  /// Longitude.
  final double lng;

  /// Requested display unit.
  final DistanceUnit unit;

  /// Serializes only fields accepted by the distance endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'lat': lat,
        'lng': lng,
        'unit': unit.wireValue,
      };
}

/// A typed distance calculation response.
final class DistanceResult {
  /// Creates an immutable distance result.
  const DistanceResult({
    required this.locationId,
    required this.location,
    required this.distance,
  });

  /// Decodes a distance response.
  factory DistanceResult.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'distanceResult');
    return DistanceResult(
      locationId: reader.string('locationId'),
      location: DistanceLocation._fromReader(reader.object('location')),
      distance: DistanceMeasurement._fromReader(reader.object('distance')),
    );
  }

  /// Requested location identifier.
  final String locationId;

  /// Location summary and coordinates.
  final DistanceLocation location;

  /// Calculated distance in both supported units.
  final DistanceMeasurement distance;
}

/// Location information embedded in a distance response.
final class DistanceLocation {
  /// Creates an immutable distance location.
  const DistanceLocation({
    required this.id,
    required this.restaurantDisplayName,
    required this.addressString,
    required this.coordinates,
  });

  /// Decodes a distance-location response.
  factory DistanceLocation.fromJson(Map<String, Object?> json) =>
      DistanceLocation._fromReader(
        JsonReader.fromObject(json, context: 'distanceLocation'),
      );

  factory DistanceLocation._fromReader(JsonReader reader) => DistanceLocation(
        id: reader.string('id'),
        restaurantDisplayName: reader.string('restaurantDisplayName'),
        addressString: reader.string('addressString'),
        coordinates: Coordinates._fromReader(reader.object('coordinates')),
      );

  /// Stable location identifier.
  final String id;

  /// Customer-facing restaurant name.
  final String restaurantDisplayName;

  /// Customer-facing address.
  final String addressString;

  /// Published location coordinates.
  final Coordinates coordinates;
}

/// A latitude and longitude pair.
final class Coordinates {
  /// Creates immutable coordinates.
  const Coordinates({required this.lat, required this.lng});

  /// Decodes published coordinates.
  factory Coordinates.fromJson(Map<String, Object?> json) =>
      Coordinates._fromReader(
        JsonReader.fromObject(json, context: 'coordinates'),
      );

  factory Coordinates._fromReader(JsonReader reader) => Coordinates(
        lat: reader.number('lat'),
        lng: reader.number('lng'),
      );

  /// Latitude.
  final double lat;

  /// Longitude.
  final double lng;
}

/// Calculated distance values.
final class DistanceMeasurement {
  /// Creates an immutable distance measurement.
  const DistanceMeasurement({
    required this.value,
    required this.unit,
    required this.miles,
    required this.kilometers,
  });

  /// Decodes a distance measurement.
  factory DistanceMeasurement.fromJson(Map<String, Object?> json) =>
      DistanceMeasurement._fromReader(
        JsonReader.fromObject(json, context: 'distanceMeasurement'),
      );

  factory DistanceMeasurement._fromReader(JsonReader reader) =>
      DistanceMeasurement(
        value: reader.number('value'),
        unit: reader.string('unit'),
        miles: reader.number('miles'),
        kilometers: reader.number('kilometers'),
      );

  /// Value in the requested unit.
  final double value;

  /// Wire unit, including future values added by the API.
  final String unit;

  /// Distance in miles.
  final double miles;

  /// Distance in kilometers.
  final double kilometers;
}

/// One restaurant-local ordering day and its time intervals.
final class OrderDay {
  /// Creates an immutable ordering day.
  OrderDay({
    required this.value,
    required this.label,
    required Iterable<String> intervals,
  }) : intervals = List<String>.unmodifiable(intervals);

  /// Decodes an ordering day.
  factory OrderDay.fromJson(Map<String, Object?> json) => OrderDay._fromReader(
        JsonReader.fromObject(json, context: 'orderDay'),
      );

  factory OrderDay._fromReader(JsonReader reader) => OrderDay(
        value: reader.string('value'),
        label: reader.string('label'),
        intervals: reader.optionalStringList('intervals'),
      );

  /// Restaurant-local date wire value.
  final String value;

  /// Customer-facing day label.
  final String label;

  /// Restaurant-local time wire values.
  final List<String> intervals;
}

/// Available order days and scheduling policy for a location.
final class OrderTimes {
  /// Creates immutable order-time information.
  OrderTimes({
    required Iterable<OrderDay> orderDays,
    required this.scheduleAllowed,
    this.requireScheduledOrders,
  }) : orderDays = List<OrderDay>.unmodifiable(orderDays);

  /// Decodes an order-times response.
  factory OrderTimes.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'orderTimes');
    return OrderTimes(
      orderDays:
          reader.optionalObjectList('orderDays').map(OrderDay._fromReader),
      scheduleAllowed: reader.boolean('scheduleAllowed'),
      requireScheduledOrders: reader.nullableBoolean('requireScheduledOrders'),
    );
  }

  /// Available restaurant-local order days.
  final List<OrderDay> orderDays;

  /// Whether customers can schedule orders.
  final bool scheduleAllowed;

  /// Whether the location requires scheduled ordering.
  final bool? requireScheduledOrders;
}

/// Waiter-tip configuration for a location.
final class GratuityConfiguration {
  /// Creates immutable gratuity configuration.
  GratuityConfiguration({
    required this.enabled,
    required this.shouldAllowCustomTip,
    required Iterable<String> tipPercentages,
    required this.defaultTipPercentage,
    this.description,
  }) : tipPercentages = List<String>.unmodifiable(tipPercentages);

  /// Decodes gratuity configuration.
  factory GratuityConfiguration.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'gratuity');
    return GratuityConfiguration(
      enabled: reader.boolean('enabled'),
      shouldAllowCustomTip: reader.boolean('shouldAllowCustomTip'),
      tipPercentages: reader.optionalStringList('tipPercentage'),
      defaultTipPercentage: reader.string('defaultTipPercentage'),
      description: reader.nullableString('description'),
    );
  }

  /// Whether tipping is enabled.
  final bool enabled;

  /// Whether customers may enter a custom tip.
  final bool shouldAllowCustomTip;

  /// Configured percentage wire values.
  final List<String> tipPercentages;

  /// Default percentage wire value.
  final String defaultTipPercentage;

  /// Optional customer-facing description.
  final String? description;
}
