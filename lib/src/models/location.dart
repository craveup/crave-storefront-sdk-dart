import '../json/json_reader.dart';
import 'common.dart';

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
      address: addressReader == null ? null : Address.fromReader(addressReader),
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
  final Address? address;

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
      location: DistanceLocation.fromReader(reader.object('location')),
      distance: DistanceMeasurement.fromReader(reader.object('distance')),
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

  /// Decodes a distance location from an existing reader.
  factory DistanceLocation.fromReader(JsonReader reader) => DistanceLocation(
        id: reader.string('id'),
        restaurantDisplayName: reader.string('restaurantDisplayName'),
        addressString: reader.string('addressString'),
        coordinates: Coordinates.fromReader(reader.object('coordinates')),
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

  /// Decodes coordinates from an existing reader.
  factory Coordinates.fromReader(JsonReader reader) => Coordinates(
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

  /// Decodes a distance measurement from an existing reader.
  factory DistanceMeasurement.fromReader(JsonReader reader) =>
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
  const OrderDay({
    required this.value,
    required this.label,
    required this.intervals,
  });

  /// Decodes an ordering day from an existing reader.
  factory OrderDay.fromReader(JsonReader reader) => OrderDay(
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
  const OrderTimes({
    required this.orderDays,
    required this.scheduleAllowed,
    this.requireScheduledOrders,
  });

  /// Decodes an order-times response.
  factory OrderTimes.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'orderTimes');
    return OrderTimes(
      orderDays: List<OrderDay>.unmodifiable(
        reader.optionalObjectList('orderDays').map(OrderDay.fromReader),
      ),
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
  const GratuityConfiguration({
    required this.enabled,
    required this.shouldAllowCustomTip,
    required this.tipPercentages,
    required this.defaultTipPercentage,
    this.description,
  });

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
