import '../json/json_reader.dart';
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
    required this.fulfillmentMethod,
    this.existingCartId,
    this.marketplaceId,
    this.channel,
    Map<String, Object?>? metadata,
    this.returnUrl,
  })  : metadata = metadata == null
            ? null
            : freezeJsonMap(metadata, context: 'orderingSession.metadata'),
        _includeExistingCartId = existingCartId != null {
    _validateReturnUrl(returnUrl);
  }

  /// Creates a request that explicitly asks the server not to resume a cart.
  StartOrderingSessionRequest.fresh({
    required this.fulfillmentMethod,
    this.marketplaceId,
    this.channel,
    Map<String, Object?>? metadata,
    this.returnUrl,
  })  : existingCartId = null,
        metadata = metadata == null
            ? null
            : freezeJsonMap(metadata, context: 'orderingSession.metadata'),
        _includeExistingCartId = true {
    _validateReturnUrl(returnUrl);
  }

  /// Requested fulfillment method.
  final FulfillmentMethod fulfillmentMethod;

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
        'fulfillmentMethod': fulfillmentMethod.wireValue,
        if (_includeExistingCartId) 'existingCartId': existingCartId,
        if (marketplaceId != null) 'marketplaceId': marketplaceId,
        if (channel != null) 'channel': channel!.wireValue,
        if (metadata != null) 'metadata': metadata,
        if (returnUrl != null) 'returnUrl': returnUrl.toString(),
      };
}

void _validateReturnUrl(Uri? returnUrl) {
  if (returnUrl != null && !returnUrl.isAbsolute) {
    throw ArgumentError('returnUrl must be an absolute URL.');
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
      cart: StorefrontCart.fromReader(reader.object('cart')),
      cartAccessToken: reader.nullableString('cartAccessToken'),
    );
  }

  /// New or resumed cart.
  final StorefrontCart cart;

  /// Guest cart capability returned only when the server issues one.
  final String? cartAccessToken;
}
