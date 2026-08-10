import '../errors.dart';
import '../http/transport.dart';
import '../models/catalog.dart';
import '../models/location.dart';
import '../models/merchant.dart';
import '../runtime/request_runtime.dart';
import 'resource_support.dart';

/// Creates merchant resources for the package facade.
MerchantsClient createMerchantsClient(
  StorefrontTransport transport,
  String merchantSlug,
) =>
    MerchantsClient._(transport, merchantSlug);

/// Creates location resources for the package facade.
LocationsClient createLocationsClient(StorefrontTransport transport) =>
    LocationsClient._(transport);

/// Creates menu resources for the package facade.
MenusClient createMenusClient(StorefrontTransport transport) =>
    MenusClient._(transport);

/// Creates product resources for the package facade.
ProductsClient createProductsClient(StorefrontTransport transport) =>
    ProductsClient._(transport);

/// Published merchant discovery operations.
final class MerchantsClient {
  const MerchantsClient._(this._transport, this._merchantSlug);

  final StorefrontTransport _transport;
  final String _merchantSlug;

  /// Gets the published merchant configured on the parent client.
  Future<Merchant> get({StorefrontRequestOptions? options}) async {
    final request = ResourceRequestOptions(options);
    final response = await _transport.send<Merchant>(
      method: 'GET',
      pathSegments: ['merchant', _merchantSlug],
      routeTemplate: '/merchant/:merchantSlug',
      decoder: (value) => Merchant.fromJson(decodeJsonObject(value)),
      timeout: request.timeout,
      cancellationToken: request.cancellationToken,
    );
    return response.data;
  }
}

/// Published location and availability operations.
final class LocationsClient {
  const LocationsClient._(this._transport);

  final StorefrontTransport _transport;

  /// Gets a published location by slug or identifier.
  Future<StorefrontLocation> get(
    String locationSlugOrId, {
    StorefrontRequestOptions? options,
  }) async {
    final request = ResourceRequestOptions(options);
    final response = await _transport.send<StorefrontLocation>(
      method: 'GET',
      pathSegments: ['locations', locationSlugOrId],
      routeTemplate: '/locations/:locationSlugOrId',
      decoder: (value) => StorefrontLocation.fromJson(decodeJsonObject(value)),
      timeout: request.timeout,
      cancellationToken: request.cancellationToken,
    );
    return response.data;
  }

  /// Calculates distance from [request] coordinates to a published location.
  Future<DistanceResult> calculateDistance(
    String locationId,
    DistanceRequest request, {
    StorefrontRequestOptions? options,
  }) async {
    final requestOptions = ResourceRequestOptions(options);
    final response = await _transport.send<DistanceResult>(
      method: 'POST',
      pathSegments: ['locations', locationId, 'distance'],
      routeTemplate: '/locations/:locationId/distance',
      body: request.toJson(),
      decoder: (value) => DistanceResult.fromJson(decodeJsonObject(value)),
      timeout: requestOptions.timeout,
      cancellationToken: requestOptions.cancellationToken,
    );
    return response.data;
  }

  /// Lists restaurant-local order days and time intervals.
  Future<OrderTimes> listTimeIntervals(
    String locationId, {
    StorefrontRequestOptions? options,
  }) async {
    final request = ResourceRequestOptions(options);
    final response = await _transport.send<OrderTimes>(
      method: 'GET',
      pathSegments: ['locations', locationId, 'time-intervals'],
      routeTemplate: '/locations/:locationId/time-intervals',
      decoder: (value) => OrderTimes.fromJson(decodeJsonObject(value)),
      timeout: request.timeout,
      cancellationToken: request.cancellationToken,
    );
    return response.data;
  }

  /// Gets the location's public gratuity configuration.
  Future<GratuityConfiguration> getGratuity(
    String locationId, {
    StorefrontRequestOptions? options,
  }) async {
    final request = ResourceRequestOptions(options);
    final response = await _transport.send<GratuityConfiguration>(
      method: 'GET',
      pathSegments: ['locations', locationId, 'gratuity'],
      routeTemplate: '/locations/:locationId/gratuity',
      decoder: (value) =>
          GratuityConfiguration.fromJson(decodeJsonObject(value)),
      timeout: request.timeout,
      cancellationToken: request.cancellationToken,
    );
    return response.data;
  }
}

/// Published location-menu operations.
final class MenusClient {
  const MenusClient._(this._transport);

  final StorefrontTransport _transport;

  /// Gets the menu bundle for a location.
  ///
  /// Use [menuOnly] for unscheduled browsing, or provide both [orderDate] and
  /// [orderTime] for availability-aware results.
  Future<MenuBundle> getForLocation(
    String locationId, {
    String? orderDate,
    String? orderTime,
    bool menuOnly = false,
    StorefrontRequestOptions? options,
  }) async {
    if (!menuOnly && (orderDate == null || orderTime == null)) {
      throw const StorefrontConfigurationException(
        'Menu requests require menuOnly=true or both orderDate and orderTime.',
      );
    }
    final request = ResourceRequestOptions(options);
    final response = await _transport.send<MenuBundle>(
      method: 'GET',
      pathSegments: ['locations', locationId, 'menus'],
      routeTemplate: '/locations/:locationId/menus',
      query: {
        if (menuOnly) 'menuOnly': true,
        if (orderDate != null) 'orderDate': orderDate,
        if (orderTime != null) 'orderTime': orderTime,
      },
      decoder: (value) => MenuBundle.fromJson(decodeJsonObject(value)),
      timeout: request.timeout,
      cancellationToken: request.cancellationToken,
    );
    return response.data;
  }
}

/// Published location-product operations.
final class ProductsClient {
  const ProductsClient._(this._transport);

  final StorefrontTransport _transport;

  /// Gets a product and its modifier tree from a published location.
  Future<Product> getForLocation(
    String locationId,
    String productId, {
    StorefrontRequestOptions? options,
  }) async {
    final request = ResourceRequestOptions(options);
    final response = await _transport.send<Product>(
      method: 'GET',
      pathSegments: ['locations', locationId, 'products', productId],
      routeTemplate: '/locations/:locationId/products/:productId',
      decoder: (value) => Product.fromJson(decodeJsonObject(value)),
      timeout: request.timeout,
      cancellationToken: request.cancellationToken,
    );
    return response.data;
  }
}
