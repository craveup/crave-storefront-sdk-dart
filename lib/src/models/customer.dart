import '../json/json_reader.dart';

/// Starts customer authentication for a merchant.
final class CustomerLoginRequest {
  /// Creates an immutable login request.
  const CustomerLoginRequest({required this.identifierString});

  /// Customer email address or phone number.
  final String identifierString;

  /// Serializes only fields accepted by the login endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'identifierString': identifierString,
      };
}

/// Challenge returned after a customer requests a one-time passcode.
final class LoginChallenge {
  /// Creates an immutable login challenge.
  const LoginChallenge({required this.methodId, required this.delivery});

  /// Decodes a login challenge.
  factory LoginChallenge.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'loginChallenge');
    return LoginChallenge(
      methodId: reader.string('methodId'),
      delivery: reader.string('delivery'),
    );
  }

  /// Authentication method identifier needed for verification.
  final String methodId;

  /// Delivery wire value, including methods added by the API later.
  final String delivery;
}

/// Verifies a customer one-time passcode.
final class VerifyOtpRequest {
  /// Creates a validated one-time-passcode request.
  VerifyOtpRequest({
    required this.identifierString,
    required this.methodId,
    required this.otp,
    this.customerName,
    this.lastName,
  }) {
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      throw ArgumentError('otp must contain exactly six digits.');
    }
  }

  /// Customer email address or phone number.
  final String identifierString;

  /// Authentication method identifier from [LoginChallenge].
  final String methodId;

  /// Six-digit one-time passcode.
  final String otp;

  /// Optional customer first or display name.
  final String? customerName;

  /// Optional customer last name.
  final String? lastName;

  /// Serializes only fields accepted by the verification endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'identifierString': identifierString,
        'methodId': methodId,
        'otp': otp,
        if (customerName != null) 'customerName': customerName,
        if (lastName != null) 'lastName': lastName,
      };
}

/// Successful customer authentication result.
final class AuthResult {
  /// Creates an immutable authentication result.
  const AuthResult({required this.token});

  /// Decodes an authentication result.
  factory AuthResult.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'authResult');
    return AuthResult(token: reader.string('token'));
  }

  /// Customer session token. Applications must store it securely.
  final String token;
}

/// Authenticated Storefront customer profile.
final class StorefrontCustomer {
  /// Creates an immutable customer profile.
  const StorefrontCustomer({
    required this.id,
    required this.customerName,
    required this.lastName,
    this.profilePicture,
    this.customerEmail,
    this.phoneNumber,
  });

  /// Decodes a customer profile.
  factory StorefrontCustomer.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'customer');
    return StorefrontCustomer(
      id: reader.string('id'),
      profilePicture: reader.nullableString('profilePicture'),
      customerEmail: reader.nullableString('customerEmail'),
      customerName: reader.string('customerName'),
      lastName: reader.string('lastName'),
      phoneNumber: reader.nullableString('phoneNumber'),
    );
  }

  /// Stable customer identifier.
  final String id;

  /// Optional profile-picture URL.
  final String? profilePicture;

  /// Customer email address.
  final String? customerEmail;

  /// Customer first or display name.
  final String customerName;

  /// Customer last name, which may be empty.
  final String lastName;

  /// Customer phone number.
  final String? phoneNumber;
}

/// Address fields accepted when creating a customer address.
final class CreateCustomerAddressRequest {
  /// Creates a validated address request.
  CreateCustomerAddressRequest({
    required this.fullAddress,
    required this.line1,
    required this.lat,
    required this.lng,
    this.line2,
    this.line3,
  }) {
    _validateCoordinates(lat, lng);
  }

  /// Full customer-facing address.
  final String fullAddress;

  /// Primary address line.
  final String line1;

  /// Optional secondary address line.
  final String? line2;

  /// Optional tertiary address line.
  final String? line3;

  /// Latitude.
  final double lat;

  /// Longitude.
  final double lng;

  /// Serializes only fields accepted by customer-address creation.
  Map<String, Object?> toJson() => <String, Object?>{
        'fullAddress': fullAddress,
        'line1': line1,
        if (line2 != null) 'line2': line2,
        if (line3 != null) 'line3': line3,
        'lat': lat,
        'lng': lng,
      };
}

/// Partial fields accepted when updating a customer address.
final class UpdateCustomerAddressRequest {
  /// Creates a validated non-empty address update.
  UpdateCustomerAddressRequest({
    this.fullAddress,
    this.line1,
    this.line2,
    this.line3,
    this.lat,
    this.lng,
  }) {
    if (fullAddress == null &&
        line1 == null &&
        line2 == null &&
        line3 == null &&
        lat == null &&
        lng == null) {
      throw ArgumentError('At least one address field must be provided.');
    }
    if (lat != null && (!lat!.isFinite || lat! < -90 || lat! > 90)) {
      throw ArgumentError('lat must be between -90 and 90.');
    }
    if (lng != null && (!lng!.isFinite || lng! < -180 || lng! > 180)) {
      throw ArgumentError('lng must be between -180 and 180.');
    }
  }

  /// Updated full customer-facing address.
  final String? fullAddress;

  /// Updated primary address line.
  final String? line1;

  /// Updated secondary address line.
  final String? line2;

  /// Updated tertiary address line.
  final String? line3;

  /// Updated latitude.
  final double? lat;

  /// Updated longitude.
  final double? lng;

  /// Serializes only fields accepted by customer-address update.
  Map<String, Object?> toJson() => <String, Object?>{
        if (fullAddress != null) 'fullAddress': fullAddress,
        if (line1 != null) 'line1': line1,
        if (line2 != null) 'line2': line2,
        if (line3 != null) 'line3': line3,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
}

/// A saved customer address.
final class CustomerAddress {
  /// Creates an immutable customer address.
  const CustomerAddress({
    required this.addressId,
    required this.fullAddress,
    required this.line1,
    required this.line2,
    required this.line3,
    required this.lat,
    required this.lng,
    required this.revision,
    required this.createdAt,
  });

  /// Decodes a customer address.
  factory CustomerAddress.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'customerAddress');
    return CustomerAddress(
      addressId: reader.string('addressId'),
      fullAddress: reader.string('fullAddress'),
      line1: reader.string('line1'),
      line2: reader.string('line2'),
      line3: reader.string('line3'),
      lat: reader.number('lat'),
      lng: reader.number('lng'),
      revision: reader.integer('revision'),
      createdAt: reader.timestamp('createdAt'),
    );
  }

  /// Stable address identifier.
  final String addressId;

  /// Full customer-facing address.
  final String fullAddress;

  /// Primary address line.
  final String line1;

  /// Secondary address line, which may be empty.
  final String line2;

  /// Tertiary address line, which may be empty.
  final String line3;

  /// Latitude.
  final double lat;

  /// Longitude.
  final double lng;

  /// Optimistic-concurrency revision.
  final int revision;

  /// ISO-8601 creation timestamp wire value.
  final String createdAt;
}

/// A compact order in a customer order list.
final class PublicOrderSummary {
  /// Creates an immutable public order summary.
  const PublicOrderSummary({
    required this.id,
    required this.shortId,
    required this.restaurantDisplayName,
    required this.fulfillmentMethod,
    required this.fulfillmentIdentifier,
    required this.pickupType,
    required this.orderTime,
    required this.orderDate,
    required this.totalQuantity,
    required this.currency,
    required this.orderTotal,
    required this.status,
    required this.createdAt,
  });

  /// Decodes an order summary.
  factory PublicOrderSummary.fromJson(Map<String, Object?> json) =>
      PublicOrderSummary._fromReader(
        JsonReader.fromObject(json, context: 'orderSummary'),
      );

  factory PublicOrderSummary._fromReader(JsonReader reader) =>
      PublicOrderSummary(
        id: reader.string('id'),
        shortId: reader.string('shortId'),
        restaurantDisplayName: reader.string('restaurantDisplayName'),
        fulfillmentMethod: reader.string('fulfillmentMethod'),
        fulfillmentIdentifier: reader.string('fulfillmentIdentifier'),
        pickupType: reader.string('pickupType'),
        orderTime: reader.string('orderTime'),
        orderDate: reader.string('orderDate'),
        totalQuantity: reader.integer('totalQuantity'),
        currency: reader.string('currency'),
        orderTotal: reader.string('orderTotal'),
        status: reader.string('status'),
        createdAt: reader.timestamp('createdAt'),
      );

  /// Stable order identifier.
  final String id;

  /// Customer-facing short order identifier.
  final String shortId;

  /// Customer-facing restaurant name.
  final String restaurantDisplayName;

  /// Fulfillment-method wire value, including future values.
  final String fulfillmentMethod;

  /// Fulfillment identifier.
  final String fulfillmentIdentifier;

  /// Pickup timing wire value.
  final String pickupType;

  /// Restaurant-local order time wire value.
  final String orderTime;

  /// Restaurant-local order date wire value.
  final String orderDate;

  /// Total item quantity.
  final int totalQuantity;

  /// Currency wire value.
  final String currency;

  /// Decimal order total.
  final String orderTotal;

  /// Order status wire value, including future values.
  final String status;

  /// ISO-8601 creation timestamp wire value.
  final String createdAt;
}

/// Full customer-visible order details.
final class PublicOrderDetail {
  /// Creates immutable public order details.
  PublicOrderDetail({
    required this.id,
    required this.shortId,
    required this.restaurantDisplayName,
    required this.fulfillmentMethod,
    required this.fulfillmentIdentifier,
    required this.pickupType,
    required this.orderTime,
    required this.orderDate,
    required this.totalQuantity,
    required this.currency,
    required this.orderTotal,
    required this.status,
    required this.createdAt,
    required this.partiallyRefunded,
    required Iterable<PublicOrderItem> items,
    required this.pricing,
    this.deliveryInfo,
    this.roomServiceInfo,
    this.tableServiceInfo,
    this.payment,
    this.updatedAt,
  }) : items = List<PublicOrderItem>.unmodifiable(items);

  /// Decodes public order details.
  factory PublicOrderDetail.fromJson(Map<String, Object?> json) =>
      PublicOrderDetail._fromReader(
        JsonReader.fromObject(json, context: 'orderDetail'),
      );

  factory PublicOrderDetail._fromReader(JsonReader reader) {
    final delivery = reader.nullableObject('deliveryInfo');
    final room = reader.nullableObject('roomServiceInfo');
    final table = reader.nullableObject('tableServiceInfo');
    final payment = reader.nullableObject('payment');
    return PublicOrderDetail(
      id: reader.string('id'),
      shortId: reader.string('shortId'),
      restaurantDisplayName: reader.string('restaurantDisplayName'),
      fulfillmentMethod: reader.string('fulfillmentMethod'),
      fulfillmentIdentifier: reader.string('fulfillmentIdentifier'),
      pickupType: reader.string('pickupType'),
      orderTime: reader.string('orderTime'),
      orderDate: reader.string('orderDate'),
      totalQuantity: reader.integer('totalQuantity'),
      currency: reader.string('currency'),
      orderTotal: reader.string('orderTotal'),
      status: reader.string('status'),
      createdAt: reader.timestamp('createdAt'),
      partiallyRefunded: reader.boolean('partiallyRefunded'),
      items:
          reader.optionalObjectList('items').map(PublicOrderItem._fromReader),
      pricing: PublicOrderPricing._fromReader(reader.object('pricing')),
      deliveryInfo: delivery == null
          ? null
          : PublicOrderDeliveryInfo._fromReader(delivery),
      roomServiceInfo:
          room == null ? null : PublicOrderRoomServiceInfo._fromReader(room),
      tableServiceInfo:
          table == null ? null : PublicOrderTableServiceInfo._fromReader(table),
      payment: payment == null ? null : PublicOrderPayment._fromReader(payment),
      updatedAt: reader.nullableTimestamp('updatedAt'),
    );
  }

  /// Stable order identifier.
  final String id;

  /// Customer-facing short order identifier.
  final String shortId;

  /// Customer-facing restaurant name.
  final String restaurantDisplayName;

  /// Fulfillment-method wire value, including future values.
  final String fulfillmentMethod;

  /// Fulfillment identifier.
  final String fulfillmentIdentifier;

  /// Pickup timing wire value.
  final String pickupType;

  /// Restaurant-local order time wire value.
  final String orderTime;

  /// Restaurant-local order date wire value.
  final String orderDate;

  /// Total item quantity.
  final int totalQuantity;

  /// Currency wire value.
  final String currency;

  /// Decimal order total.
  final String orderTotal;

  /// Order status wire value, including future values.
  final String status;

  /// ISO-8601 creation timestamp wire value.
  final String createdAt;

  /// Whether this order has a partial refund.
  final bool partiallyRefunded;

  /// Customer-visible order items.
  final List<PublicOrderItem> items;

  /// Customer-visible pricing breakdown.
  final PublicOrderPricing pricing;

  /// Delivery information when applicable.
  final PublicOrderDeliveryInfo? deliveryInfo;

  /// Room-service information when applicable.
  final PublicOrderRoomServiceInfo? roomServiceInfo;

  /// Table-service information when applicable.
  final PublicOrderTableServiceInfo? tableServiceInfo;

  /// Redacted payment information.
  final PublicOrderPayment? payment;

  /// ISO-8601 update timestamp wire value.
  final String? updatedAt;
}

/// A customer-visible order item.
final class PublicOrderItem {
  /// Creates an immutable public order item.
  PublicOrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
    required this.discount,
    required this.specialInstructions,
    required Iterable<PublicOrderModifier> modifiers,
  }) : modifiers = List<PublicOrderModifier>.unmodifiable(modifiers);

  /// Decodes a customer-visible order item.
  factory PublicOrderItem.fromJson(Map<String, Object?> json) =>
      PublicOrderItem._fromReader(
        JsonReader.fromObject(json, context: 'publicOrderItem'),
      );

  factory PublicOrderItem._fromReader(JsonReader reader) => PublicOrderItem(
        id: reader.string('id'),
        name: reader.string('name'),
        quantity: reader.integer('quantity'),
        price: reader.string('price'),
        total: reader.string('total'),
        discount: reader.string('discount'),
        specialInstructions: reader.string('specialInstructions'),
        modifiers: reader
            .optionalObjectList('modifiers')
            .map(PublicOrderModifier._fromReader),
      );

  /// Stable order-item identifier.
  final String id;

  /// Customer-facing item name.
  final String name;

  /// Ordered quantity.
  final int quantity;

  /// Decimal unit price.
  final String price;

  /// Decimal line total.
  final String total;

  /// Decimal line discount.
  final String discount;

  /// Customer-entered special instructions.
  final String specialInstructions;

  /// Selected modifiers.
  final List<PublicOrderModifier> modifiers;
}

/// A customer-visible order modifier.
final class PublicOrderModifier {
  /// Creates an immutable order modifier.
  const PublicOrderModifier({
    required this.groupName,
    required this.name,
    required this.quantity,
    required this.price,
  });

  /// Decodes a customer-visible order modifier.
  factory PublicOrderModifier.fromJson(Map<String, Object?> json) =>
      PublicOrderModifier._fromReader(
        JsonReader.fromObject(json, context: 'publicOrderModifier'),
      );

  factory PublicOrderModifier._fromReader(JsonReader reader) =>
      PublicOrderModifier(
        groupName: reader.string('groupName'),
        name: reader.string('name'),
        quantity: reader.integer('quantity'),
        price: reader.string('price'),
      );

  /// Customer-facing modifier-group name.
  final String groupName;

  /// Customer-facing modifier name.
  final String name;

  /// Selected quantity.
  final int quantity;

  /// Decimal modifier price.
  final String price;
}

/// Customer-visible order pricing.
final class PublicOrderPricing {
  /// Creates an immutable pricing breakdown.
  const PublicOrderPricing({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.tip,
    required this.serviceFee,
    required this.fulfillmentFee,
    required this.enterpriseFee,
    required this.total,
    required this.refunded,
    required this.netPaid,
  });

  /// Decodes customer-visible order pricing.
  factory PublicOrderPricing.fromJson(Map<String, Object?> json) =>
      PublicOrderPricing._fromReader(
        JsonReader.fromObject(json, context: 'publicOrderPricing'),
      );

  factory PublicOrderPricing._fromReader(JsonReader reader) =>
      PublicOrderPricing(
        subtotal: reader.string('subtotal'),
        discount: reader.string('discount'),
        tax: reader.string('tax'),
        tip: reader.string('tip'),
        serviceFee: reader.string('serviceFee'),
        fulfillmentFee: reader.string('fulfillmentFee'),
        enterpriseFee: reader.string('enterpriseFee'),
        total: reader.string('total'),
        refunded: reader.string('refunded'),
        netPaid: reader.string('netPaid'),
      );

  /// Decimal subtotal.
  final String subtotal;

  /// Decimal discount total.
  final String discount;

  /// Decimal tax total.
  final String tax;

  /// Decimal tip total.
  final String tip;

  /// Decimal service-fee total.
  final String serviceFee;

  /// Decimal fulfillment-fee total.
  final String fulfillmentFee;

  /// Decimal enterprise-fee total.
  final String enterpriseFee;

  /// Decimal order total.
  final String total;

  /// Decimal refunded amount.
  final String refunded;

  /// Decimal net-paid amount.
  final String netPaid;
}

/// Redacted payment details for a public order.
final class PublicOrderPayment {
  /// Creates immutable redacted payment details.
  const PublicOrderPayment({this.cardLast4, this.walletType, this.cardBrand});

  /// Decodes redacted order payment details.
  factory PublicOrderPayment.fromJson(Map<String, Object?> json) =>
      PublicOrderPayment._fromReader(
        JsonReader.fromObject(json, context: 'publicOrderPayment'),
      );

  factory PublicOrderPayment._fromReader(JsonReader reader) =>
      PublicOrderPayment(
        cardLast4: reader.nullableString('cardLast4'),
        walletType: reader.nullableString('walletType'),
        cardBrand: reader.nullableString('cardBrand'),
      );

  /// Last four card digits.
  final String? cardLast4;

  /// Wallet type wire value.
  final String? walletType;

  /// Card-brand wire value.
  final String? cardBrand;
}

/// Delivery details for a public order.
final class PublicOrderDeliveryInfo {
  /// Creates immutable delivery details.
  const PublicOrderDeliveryInfo({this.deliveryAddress});

  /// Decodes public order delivery details.
  factory PublicOrderDeliveryInfo.fromJson(Map<String, Object?> json) =>
      PublicOrderDeliveryInfo._fromReader(
        JsonReader.fromObject(json, context: 'publicOrderDeliveryInfo'),
      );

  factory PublicOrderDeliveryInfo._fromReader(JsonReader reader) =>
      PublicOrderDeliveryInfo(
        deliveryAddress: reader.nullableString('deliveryAddress'),
      );

  /// Customer-facing delivery address.
  final String? deliveryAddress;
}

/// Room-service details for a public order.
final class PublicOrderRoomServiceInfo {
  /// Creates immutable room-service details.
  const PublicOrderRoomServiceInfo({this.lastName, this.roomNumber});

  /// Decodes public order room-service details.
  factory PublicOrderRoomServiceInfo.fromJson(Map<String, Object?> json) =>
      PublicOrderRoomServiceInfo._fromReader(
        JsonReader.fromObject(json, context: 'publicOrderRoomServiceInfo'),
      );

  factory PublicOrderRoomServiceInfo._fromReader(JsonReader reader) =>
      PublicOrderRoomServiceInfo(
        lastName: reader.nullableString('lastName'),
        roomNumber: reader.nullableString('roomNumber'),
      );

  /// Guest last name.
  final String? lastName;

  /// Room number.
  final String? roomNumber;
}

/// Table-service details for a public order.
final class PublicOrderTableServiceInfo {
  /// Creates immutable table-service details.
  const PublicOrderTableServiceInfo({this.tableNumber});

  /// Decodes public order table-service details.
  factory PublicOrderTableServiceInfo.fromJson(Map<String, Object?> json) =>
      PublicOrderTableServiceInfo._fromReader(
        JsonReader.fromObject(json, context: 'publicOrderTableServiceInfo'),
      );

  factory PublicOrderTableServiceInfo._fromReader(JsonReader reader) =>
      PublicOrderTableServiceInfo(
        tableNumber: reader.nullableString('tableNumber'),
      );

  /// Table number.
  final String? tableNumber;
}

/// A customer saved payment method.
final class SavedPaymentMethod {
  /// Creates an immutable saved payment method.
  const SavedPaymentMethod({
    required this.id,
    this.brand,
    this.displayBrand,
    this.expMonth,
    this.expYear,
    this.last4,
  });

  /// Decodes a saved payment method.
  factory SavedPaymentMethod.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'savedPayment');
    return SavedPaymentMethod(
      id: reader.string('id'),
      brand: reader.nullableString('brand'),
      displayBrand: reader.nullableString('displayBrand'),
      expMonth: reader.nullableInteger('expMonth'),
      expYear: reader.nullableInteger('expYear'),
      last4: reader.nullableString('last4'),
    );
  }

  /// Stable provider payment-method identifier.
  final String id;

  /// Card-brand wire value.
  final String? brand;

  /// Customer-facing card brand.
  final String? displayBrand;

  /// Expiration month.
  final int? expMonth;

  /// Expiration year.
  final int? expYear;

  /// Last four card digits.
  final String? last4;
}

/// Result of deleting a saved customer address.
final class DeleteCustomerAddressResult {
  /// Creates an immutable address-deletion result.
  const DeleteCustomerAddressResult({
    required this.success,
    required this.addressId,
  });

  /// Decodes an address-deletion result.
  factory DeleteCustomerAddressResult.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'addressDeletion');
    return DeleteCustomerAddressResult(
      success: reader.boolean('success'),
      addressId: reader.string('addressId'),
    );
  }

  /// Whether the deletion succeeded.
  final bool success;

  /// Deleted address identifier.
  final String addressId;
}

/// A generic successful mutation response.
final class SuccessResult {
  /// Creates an immutable success result.
  const SuccessResult({required this.success});

  /// Decodes a success response.
  factory SuccessResult.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'success');
    return SuccessResult(success: reader.boolean('success'));
  }

  /// Whether the operation succeeded.
  final bool success;
}

void _validateCoordinates(double lat, double lng) {
  if (!lat.isFinite || lat < -90 || lat > 90) {
    throw ArgumentError('lat must be between -90 and 90.');
  }
  if (!lng.isFinite || lng < -180 || lng > 180) {
    throw ArgumentError('lng must be between -180 and 180.');
  }
}
