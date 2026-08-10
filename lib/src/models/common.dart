import '../json/json_reader.dart';

/// A postal address returned by a Storefront location or cart.
final class Address {
  /// Creates an immutable address.
  const Address({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
    required this.lat,
    required this.lng,
    this.streetOptional,
  });

  /// Decodes an address from Storefront JSON.
  factory Address.fromJson(Map<String, Object?> json) =>
      Address._fromReader(JsonReader.fromObject(json, context: 'address'));

  factory Address._fromReader(JsonReader reader) => Address(
        street: reader.string('street'),
        streetOptional: reader.nullableString('streetOptional'),
        city: reader.string('city'),
        state: reader.string('state'),
        zipCode: reader.string('zipCode'),
        country: reader.string('country'),
        lat: reader.number('lat'),
        lng: reader.number('lng'),
      );

  /// Primary street line.
  final String street;

  /// Optional secondary street line.
  final String? streetOptional;

  /// City name.
  final String city;

  /// State, province, or region.
  final String state;

  /// Postal code.
  final String zipCode;

  /// Country name or code supplied by the API.
  final String country;

  /// Latitude.
  final double lat;

  /// Longitude.
  final double lng;
}

/// Country accepted by the Storefront delivery-address endpoint.
enum SupportedCountry {
  /// United States.
  unitedStates('United States'),

  /// United Arab Emirates.
  unitedArabEmirates('United Arab Emirates'),

  /// Australia.
  australia('Australia'),

  /// United Kingdom.
  unitedKingdom('United Kingdom');

  const SupportedCountry(this.wireValue);

  /// Value sent to the Storefront API.
  final String wireValue;
}

/// A structured delivery address accepted by a cart request.
final class DeliveryAddressRequest {
  /// Creates a validated delivery address.
  DeliveryAddressRequest({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
    required this.lat,
    required this.lng,
    this.streetOptional,
  }) {
    if (!lat.isFinite || lat < -90 || lat > 90) {
      throw ArgumentError('lat must be between -90 and 90.');
    }
    if (!lng.isFinite || lng < -180 || lng > 180) {
      throw ArgumentError('lng must be between -180 and 180.');
    }
  }

  /// Primary street line.
  final String street;

  /// Optional secondary street line.
  final String? streetOptional;

  /// City name.
  final String city;

  /// State, province, or region.
  final String state;

  /// Postal code.
  final String zipCode;

  /// Supported destination country.
  final SupportedCountry country;

  /// Latitude.
  final double lat;

  /// Longitude.
  final double lng;

  /// Serializes only fields accepted by the delivery endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'street': street,
        if (streetOptional != null) 'streetOptional': streetOptional,
        'city': city,
        'state': state,
        'zipCode': zipCode,
        'country': country.wireValue,
        'lat': lat,
        'lng': lng,
      };
}

/// A cursor-based page returned by a customer endpoint.
final class CursorPage<T> {
  /// Creates an immutable cursor page.
  CursorPage({required Iterable<T> items, required this.nextCursor})
      : items = List<T>.unmodifiable(items);

  /// Decodes a cursor page using [decodeItem] for each entry.
  factory CursorPage.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, Object?> json) decodeItem,
  ) {
    final reader = JsonReader.fromObject(json, context: 'cursorPage');
    return CursorPage<T>(
      items: reader.objectList('items').map(
            (item) => decodeItem(item.asMap()),
          ),
      nextCursor: reader.nullableString('nextCursor'),
    );
  }

  /// Items in this page.
  final List<T> items;

  /// Cursor for the next page, or null when this is the last page.
  final String? nextCursor;
}
