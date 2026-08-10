import '../json/json_reader.dart';

/// A merchant and its published Storefront locations.
final class Merchant {
  /// Creates an immutable merchant.
  const Merchant({
    required this.id,
    required this.name,
    required this.country,
    required this.currency,
    required this.locations,
    this.bio,
    this.logo,
    this.cover,
  });

  /// Decodes a merchant response and ignores unknown additive fields.
  factory Merchant.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'merchant');
    return Merchant(
      id: reader.string('id'),
      name: reader.string('name'),
      country: reader.string('country'),
      currency: reader.string('currency'),
      bio: reader.nullableString('bio'),
      logo: reader.nullableString('logo'),
      cover: reader.nullableString('cover'),
      locations: List<MerchantLocation>.unmodifiable(
        reader.optionalObjectList('locations').map(MerchantLocation.fromReader),
      ),
    );
  }

  /// Stable merchant identifier.
  final String id;

  /// Merchant display name.
  final String name;

  /// Country value returned by the API.
  final String country;

  /// Lowercase currency value returned by the API.
  final String currency;

  /// Optional merchant biography.
  final String? bio;

  /// Optional logo URL.
  final String? logo;

  /// Optional cover-image URL.
  final String? cover;

  /// Published merchant locations.
  final List<MerchantLocation> locations;
}

/// A published location embedded in a merchant response.
final class MerchantLocation {
  /// Creates an immutable merchant location.
  const MerchantLocation({
    required this.id,
    required this.restaurantDisplayName,
    required this.addressString,
    required this.methods,
    this.coverPhoto,
    this.restaurantLogo,
    this.restaurantBio,
    this.lat,
    this.lng,
  });

  /// Decodes a location from an existing reader.
  factory MerchantLocation.fromReader(JsonReader reader) => MerchantLocation(
        id: reader.string('id'),
        restaurantDisplayName: reader.string('restaurantDisplayName'),
        coverPhoto: reader.nullableString('coverPhoto'),
        restaurantLogo: reader.nullableString('restaurantLogo'),
        addressString: reader.string('addressString'),
        restaurantBio: reader.nullableString('restaurantBio'),
        lat: reader.nullableNumber('lat'),
        lng: reader.nullableNumber('lng'),
        methods: MerchantFulfillmentMethods.fromReader(
          reader.object('methodsStatus'),
        ),
      );

  /// Stable location identifier.
  final String id;

  /// Customer-facing restaurant name.
  final String restaurantDisplayName;

  /// Optional cover-image URL.
  final String? coverPhoto;

  /// Optional restaurant-logo URL.
  final String? restaurantLogo;

  /// Customer-facing address.
  final String addressString;

  /// Optional restaurant biography.
  final String? restaurantBio;

  /// Latitude, when the merchant has published it.
  final double? lat;

  /// Longitude, when the merchant has published it.
  final double? lng;

  /// Available fulfillment methods.
  final MerchantFulfillmentMethods methods;
}

/// Fulfillment-method availability for a merchant location.
final class MerchantFulfillmentMethods {
  /// Creates immutable method availability.
  const MerchantFulfillmentMethods({
    required this.pickup,
    required this.table,
    required this.delivery,
    required this.roomService,
  });

  /// Decodes availability from an existing reader.
  factory MerchantFulfillmentMethods.fromReader(JsonReader reader) =>
      MerchantFulfillmentMethods(
        pickup: reader.boolean('pickup'),
        table: reader.boolean('table'),
        delivery: reader.boolean('delivery'),
        roomService: reader.boolean('roomService'),
      );

  /// Whether takeout or pickup is available.
  final bool pickup;

  /// Whether table-side ordering is available.
  final bool table;

  /// Whether delivery is available.
  final bool delivery;

  /// Whether room service is available.
  final bool roomService;
}
