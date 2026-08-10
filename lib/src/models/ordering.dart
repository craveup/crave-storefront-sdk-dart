import '../json/json_reader.dart';
import '../json/request_metadata.dart';
import 'cart.dart';

/// Origin channel accepted by an ordering-session request.
enum OrderChannel {
  /// QR-code storefront.
  qr('qr'),

  /// Web storefront.
  web('web'),

  /// Kiosk storefront.
  kiosk('kiosk'),

  /// Native application.
  app('app'),

  /// Point-of-sale system.
  pos('pos'),

  /// Origin is not known.
  unknown('unknown');

  const OrderChannel(this.wireValue);

  /// Value sent to the Storefront API.
  final String wireValue;
}

/// Parameters used to start or resume an ordering session.
final class StartOrderingSessionRequest {
  /// Creates a request that may resume [existingCartId].
  StartOrderingSessionRequest({
    required String fulfillmentMethod,
    this.existingCartId,
    this.marketplaceId,
    this.channel,
    Map<String, Object?>? metadata,
    this.returnUrl,
  })  : fulfillmentMethod = _validateFulfillmentMethod(fulfillmentMethod),
        metadata = prepareStorefrontMetadata(
          metadata,
          context: 'orderingSession.metadata',
        ),
        _includeExistingCartId = existingCartId != null {
    _validateReturnUrl(returnUrl);
    _validateMetadata(this.metadata);
    validateStorefrontPayloadSize(toJson());
  }

  /// Creates a request that explicitly asks the server not to resume a cart.
  StartOrderingSessionRequest.fresh({
    required String fulfillmentMethod,
    this.marketplaceId,
    this.channel,
    Map<String, Object?>? metadata,
    this.returnUrl,
  })  : fulfillmentMethod = _validateFulfillmentMethod(fulfillmentMethod),
        existingCartId = null,
        metadata = prepareStorefrontMetadata(
          metadata,
          context: 'orderingSession.metadata',
        ),
        _includeExistingCartId = true {
    _validateReturnUrl(returnUrl);
    _validateMetadata(this.metadata);
    validateStorefrontPayloadSize(toJson());
  }

  /// Requested fulfillment method.
  final String fulfillmentMethod;

  /// Existing cart identifier to resume.
  final String? existingCartId;

  /// Optional storefront marketplace identifier.
  final String? marketplaceId;

  /// Origin channel.
  final OrderChannel? channel;

  /// Caller-defined, non-sensitive metadata.
  final Map<String, Object?>? metadata;

  /// Caller-approved return URL.
  final Uri? returnUrl;

  final bool _includeExistingCartId;

  /// Serializes only fields accepted by the ordering-session endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'fulfillmentMethod': fulfillmentMethod,
        if (_includeExistingCartId) 'existingCartId': existingCartId,
        if (marketplaceId != null) 'marketplaceId': marketplaceId,
        if (channel != null) 'channel': channel!.wireValue,
        if (metadata != null) 'metadata': metadata,
        if (returnUrl != null) 'returnUrl': returnUrl.toString(),
      };
}

String _validateFulfillmentMethod(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 64) {
    throw ArgumentError(
      'fulfillmentMethod must contain 1 to 64 non-whitespace characters.',
    );
  }
  return trimmed;
}

void _validateMetadata(Map<String, Object?>? metadata) {
  if (metadata?.containsKey('returnUrl') ?? false) {
    throw ArgumentError(
      'metadata.returnUrl is reserved; use the top-level returnUrl field.',
    );
  }
}

void _validateReturnUrl(Uri? returnUrl) {
  if (returnUrl == null) {
    return;
  }
  const reservedSchemes = <String>{
    'blob',
    'data',
    'file',
    'javascript',
  };
  final scheme = returnUrl.scheme.toLowerCase();
  final validWebHost =
      (scheme != 'http' && scheme != 'https') || returnUrl.host.isNotEmpty;
  if (!returnUrl.isAbsolute ||
      !validWebHost ||
      reservedSchemes.contains(scheme) ||
      returnUrl.toString().length > 2048) {
    throw ArgumentError(
      'returnUrl must be an allowed absolute URL of at most 2048 characters.',
    );
  }
}

/// Result of starting or resuming an ordering session.
final class StartOrderingSessionResult {
  /// Creates an immutable ordering-session result.
  const StartOrderingSessionResult({required this.cart, this.cartAccessToken});

  /// Decodes an ordering-session response.
  factory StartOrderingSessionResult.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'orderingSession');
    return StartOrderingSessionResult(
      cart: StorefrontCart.fromJson(reader.object('cart').asMap()),
      cartAccessToken: reader.nullableString('cartAccessToken'),
    );
  }

  /// New or resumed cart.
  final StorefrontCart cart;

  /// Guest cart capability returned only when the server issues one.
  final String? cartAccessToken;
}
