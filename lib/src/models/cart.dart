import '../json/json_reader.dart';
import 'catalog.dart';
import 'common.dart';

/// Fulfillment method accepted by cart update requests.
enum FulfillmentMethod {
  /// Customer pickup or takeout.
  takeout('takeout'),

  /// Table-side service.
  tableSide('table_side'),

  /// Hotel or venue room service.
  roomService('room_service'),

  /// Delivery to an address.
  delivery('delivery');

  const FulfillmentMethod(this.wireValue);

  /// Value sent to the Storefront API.
  final String wireValue;
}

/// Requested order timing.
enum OrderTiming {
  /// As soon as possible.
  asap('ASAP'),

  /// A restaurant-local scheduled time.
  scheduled('LATER');

  const OrderTiming(this.wireValue);

  /// Value sent to the Storefront API.
  final String wireValue;
}

/// Action to take when a cart item becomes unavailable.
enum ItemUnavailableAction {
  /// Remove only the unavailable item.
  removeItem('remove_item'),

  /// Cancel the entire order.
  cancelEntireOrder('cancel_entire_order');

  const ItemUnavailableAction(this.wireValue);

  /// Value sent to the Storefront API.
  final String wireValue;
}

/// A cart returned by the Storefront API.
final class StorefrontCart {
  /// Creates an immutable cart.
  StorefrontCart({
    required this.id,
    required this.locationId,
    required this.status,
    required this.revision,
    required this.fulfilmentMethod,
    required this.totalQuantity,
    required Iterable<CartItem> items,
    this.merchantId,
    this.lockedAt,
    this.expiresAt,
    this.restaurantDisplayName,
    this.fulfillmentIdentifier,
    Map<String, Object?>? metadata,
    this.pickupType,
    this.orderDate,
    this.orderTime,
    this.currency,
    this.subTotal,
    this.subTotalFormatted,
    this.discountTotal,
    this.discountTotalFormatted,
    this.waiterTipTotal,
    this.waiterTipTotalFormatted,
    this.taxTotal,
    this.taxTotalFormatted,
    this.taxAndFeeTotal,
    this.taxAndFeeTotalFormatted,
    this.serviceFeeTotal,
    this.serviceFeeTotalFormatted,
    this.paymentProcessingFeeTotal,
    this.paymentProcessingFeeTotalFormatted,
    this.applicationFeeTotal,
    this.applicationFeeTotalFormatted,
    this.netSalesTotal,
    this.netSalesTotalFormatted,
    this.fulfillmentMethodFeeTotal,
    this.fulfillmentMethodFeeTotalFormatted,
    this.orderTotal,
    this.orderTotalFormatted,
    this.orderTotalWithServiceFee,
    this.orderTotalWithServiceFeeFormatted,
    this.orderTotalWithServiceFeeAmount,
    this.enterpriseFeeTotal,
    this.enterpriseFeeTotalFormatted,
    this.subTotalWithoutDiscount,
    this.subTotalWithoutDiscountFormatted,
    this.discountCode,
    this.statementDescriptor,
    this.fees,
    this.deliveryInfo,
    this.tableServiceInfo,
    this.roomServiceInfo,
  })  : items = List<CartItem>.unmodifiable(items),
        metadata = metadata == null
            ? null
            : freezeJsonMap(metadata, context: 'cart.metadata');

  /// Decodes a cart response and ignores unknown additive fields.
  factory StorefrontCart.fromJson(Map<String, Object?> json) =>
      StorefrontCart._fromReader(
        JsonReader.fromObject(json, context: 'cart'),
      );

  factory StorefrontCart._fromReader(JsonReader reader) {
    final fees = reader.nullableObject('fees');
    final delivery = reader.nullableObject('deliveryInfo');
    final table = reader.nullableObject('tableServiceInfo');
    final room = reader.nullableObject('roomServiceInfo');
    return StorefrontCart(
      id: reader.string('id'),
      locationId: reader.string('locationId'),
      merchantId: reader.nullableString('merchantId'),
      status: reader.string('status'),
      lockedAt: reader.nullableTimestamp('lockedAt'),
      revision: reader.integer('revision'),
      expiresAt: reader.nullableTimestamp('expiresAt'),
      restaurantDisplayName: reader.nullableString('restaurantDisplayName'),
      fulfilmentMethod: reader.string('fulfilmentMethod'),
      fulfillmentIdentifier: reader.nullableString('fulfillmentIdentifier'),
      metadata: reader.nullableMap('metadata'),
      pickupType: reader.nullableString('pickupType'),
      orderDate: reader.nullableString('orderDate'),
      orderTime: reader.nullableString('orderTime'),
      currency: reader.nullableString('currency'),
      subTotal: reader.nullableString('subTotal'),
      subTotalFormatted: reader.nullableString('subTotalFormatted'),
      discountTotal: reader.nullableString('discountTotal'),
      discountTotalFormatted: reader.nullableString('discountTotalFormatted'),
      waiterTipTotal: reader.nullableString('waiterTipTotal'),
      waiterTipTotalFormatted: reader.nullableString('waiterTipTotalFormatted'),
      taxTotal: reader.nullableString('taxTotal'),
      taxTotalFormatted: reader.nullableString('taxTotalFormatted'),
      taxAndFeeTotal: reader.nullableString('taxAndFeeTotal'),
      taxAndFeeTotalFormatted: reader.nullableString('taxAndFeeTotalFormatted'),
      serviceFeeTotal: reader.nullableString('serviceFeeTotal'),
      serviceFeeTotalFormatted:
          reader.nullableString('serviceFeeTotalFormatted'),
      paymentProcessingFeeTotal:
          reader.nullableString('paymentProcessingFeeTotal'),
      paymentProcessingFeeTotalFormatted:
          reader.nullableString('paymentProcessingFeeTotalFormatted'),
      applicationFeeTotal: reader.nullableString('applicationFeeTotal'),
      applicationFeeTotalFormatted:
          reader.nullableString('applicationFeeTotalFormatted'),
      netSalesTotal: reader.nullableString('netSalesTotal'),
      netSalesTotalFormatted: reader.nullableString('netSalesTotalFormatted'),
      fulfillmentMethodFeeTotal:
          reader.nullableString('fulfillmentMethodFeeTotal'),
      fulfillmentMethodFeeTotalFormatted:
          reader.nullableString('fulfillmentMethodFeeTotalFormatted'),
      orderTotal: reader.nullableString('orderTotal'),
      orderTotalFormatted: reader.nullableString('orderTotalFormatted'),
      orderTotalWithServiceFee:
          reader.nullableString('orderTotalWithServiceFee'),
      orderTotalWithServiceFeeFormatted:
          reader.nullableString('orderTotalWithServiceFeeFormatted'),
      orderTotalWithServiceFeeAmount:
          reader.nullableNumber('orderTotalWithServiceFeeAmount'),
      enterpriseFeeTotal: reader.nullableString('enterpriseFeeTotal'),
      enterpriseFeeTotalFormatted:
          reader.nullableString('enterpriseFeeTotalFormatted'),
      subTotalWithoutDiscount: reader.nullableString('subTotalWithoutDiscount'),
      subTotalWithoutDiscountFormatted:
          reader.nullableString('subTotalWithoutDiscountFormatted'),
      discountCode: reader.nullableString('discountCode'),
      statementDescriptor: reader.nullableString('statementDescriptor'),
      totalQuantity: reader.integer('totalQuantity'),
      items: reader.objectList('items').map(CartItem._fromReader),
      fees: fees == null ? null : CartFees._fromReader(fees),
      deliveryInfo:
          delivery == null ? null : CartDeliveryInfo._fromReader(delivery),
      tableServiceInfo:
          table == null ? null : CartTableServiceInfo._fromReader(table),
      roomServiceInfo:
          room == null ? null : CartRoomServiceInfo._fromReader(room),
    );
  }

  /// Stable cart identifier.
  final String id;

  /// Owning location identifier.
  final String locationId;

  /// Owning merchant identifier, when included.
  final String? merchantId;

  /// Cart status wire value, including future values.
  final String status;

  /// Lock timestamp wire value, when the cart is locked.
  final String? lockedAt;

  /// Optimistic-concurrency revision.
  final int revision;

  /// Expiration timestamp wire value.
  final String? expiresAt;

  /// Customer-facing restaurant name.
  final String? restaurantDisplayName;

  /// Fulfillment-method wire value returned with the API's British spelling.
  final String fulfilmentMethod;

  /// Optional fulfillment identifier.
  final String? fulfillmentIdentifier;

  /// Non-sensitive cart metadata returned by the API.
  final Map<String, Object?>? metadata;

  /// Pickup timing wire value.
  final String? pickupType;

  /// Restaurant-local order date wire value.
  final String? orderDate;

  /// Restaurant-local order time wire value.
  final String? orderTime;

  /// Currency wire value.
  final String? currency;

  /// Decimal subtotal.
  final String? subTotal;

  /// Preformatted subtotal.
  final String? subTotalFormatted;

  /// Decimal discount total.
  final String? discountTotal;

  /// Preformatted discount total.
  final String? discountTotalFormatted;

  /// Decimal waiter-tip total.
  final String? waiterTipTotal;

  /// Preformatted waiter-tip total.
  final String? waiterTipTotalFormatted;

  /// Decimal tax total.
  final String? taxTotal;

  /// Preformatted tax total.
  final String? taxTotalFormatted;

  /// Decimal tax-and-fee total.
  final String? taxAndFeeTotal;

  /// Preformatted tax-and-fee total.
  final String? taxAndFeeTotalFormatted;

  /// Decimal service-fee total.
  final String? serviceFeeTotal;

  /// Preformatted service-fee total.
  final String? serviceFeeTotalFormatted;

  /// Decimal payment-processing total.
  final String? paymentProcessingFeeTotal;

  /// Preformatted payment-processing total.
  final String? paymentProcessingFeeTotalFormatted;

  /// Decimal application-fee total.
  final String? applicationFeeTotal;

  /// Preformatted application-fee total.
  final String? applicationFeeTotalFormatted;

  /// Decimal net-sales total.
  final String? netSalesTotal;

  /// Preformatted net-sales total.
  final String? netSalesTotalFormatted;

  /// Decimal fulfillment-fee total.
  final String? fulfillmentMethodFeeTotal;

  /// Preformatted fulfillment-fee total.
  final String? fulfillmentMethodFeeTotalFormatted;

  /// Decimal order total.
  final String? orderTotal;

  /// Preformatted order total.
  final String? orderTotalFormatted;

  /// Decimal total including the service fee.
  final String? orderTotalWithServiceFee;

  /// Preformatted total including the service fee.
  final String? orderTotalWithServiceFeeFormatted;

  /// Numeric total retained for compatibility with the current API response.
  final double? orderTotalWithServiceFeeAmount;

  /// Decimal enterprise-fee total.
  final String? enterpriseFeeTotal;

  /// Preformatted enterprise-fee total.
  final String? enterpriseFeeTotalFormatted;

  /// Decimal subtotal before discount.
  final String? subTotalWithoutDiscount;

  /// Preformatted subtotal before discount.
  final String? subTotalWithoutDiscountFormatted;

  /// Applied discount code.
  final String? discountCode;

  /// Payment statement descriptor.
  final String? statementDescriptor;

  /// Total item quantity.
  final int totalQuantity;

  /// Cart items.
  final List<CartItem> items;

  /// Fee-rate configuration returned by the API.
  final CartFees? fees;

  /// Delivery details when delivery is selected.
  final CartDeliveryInfo? deliveryInfo;

  /// Table details when table-side service is selected.
  final CartTableServiceInfo? tableServiceInfo;

  /// Room details when room service is selected.
  final CartRoomServiceInfo? roomServiceInfo;
}

/// A line item in a Storefront cart.
final class CartItem {
  /// Creates an immutable cart item.
  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.total,
    required this.itemUnavailableAction,
    required Iterable<CartModifierGroup> selections,
    this.description,
    this.imageUrl,
    this.priceFormatted,
    this.totalFormatted,
    this.discount,
    this.discountFormatted,
    this.categoryId,
    this.specialInstructions,
    this.product,
  }) : selections = List<CartModifierGroup>.unmodifiable(selections);

  /// Decodes a cart-item response.
  factory CartItem.fromJson(Map<String, Object?> json) => CartItem._fromReader(
        JsonReader.fromObject(json, context: 'cartItem'),
      );

  factory CartItem._fromReader(JsonReader reader) {
    final product = reader.nullableObject('product');
    return CartItem(
      id: reader.string('id'),
      productId: reader.string('productId'),
      name: reader.string('name'),
      description: reader.nullableString('description'),
      imageUrl: reader.nullableString('imageUrl'),
      price: reader.string('price'),
      priceFormatted: reader.nullableString('priceFormatted'),
      quantity: reader.integer('quantity'),
      total: reader.string('total'),
      totalFormatted: reader.nullableString('totalFormatted'),
      discount: reader.nullableString('discount'),
      discountFormatted: reader.nullableString('discountFormatted'),
      categoryId: reader.nullableString('categoryId'),
      specialInstructions: reader.nullableString('specialInstructions'),
      itemUnavailableAction: reader.string('itemUnavailableAction'),
      selections: reader
          .optionalObjectList('selections')
          .map(CartModifierGroup._fromReader),
      product: product == null ? null : CartProductSummary._fromReader(product),
    );
  }

  /// Stable cart-item identifier.
  final String id;

  /// Stable product identifier.
  final String productId;

  /// Customer-facing product name.
  final String name;

  /// Optional product description.
  final String? description;

  /// Optional product-image URL.
  final String? imageUrl;

  /// Decimal unit price.
  final String price;

  /// Preformatted unit price.
  final String? priceFormatted;

  /// Selected quantity.
  final int quantity;

  /// Decimal line total.
  final String total;

  /// Preformatted line total.
  final String? totalFormatted;

  /// Decimal line discount.
  final String? discount;

  /// Preformatted line discount.
  final String? discountFormatted;

  /// Source menu-category identifier.
  final String? categoryId;

  /// Customer-entered special instructions.
  final String? specialInstructions;

  /// Unavailable-item action wire value, including future values.
  final String itemUnavailableAction;

  /// Selected modifier groups.
  final List<CartModifierGroup> selections;

  /// Optional embedded product summary.
  final CartProductSummary? product;
}

/// A selected modifier group stored on a cart item.
final class CartModifierGroup {
  /// Creates an immutable selected modifier group.
  CartModifierGroup({
    required this.id,
    required this.name,
    required this.rule,
    required Iterable<CartModifierItem> items,
  }) : items = List<CartModifierItem>.unmodifiable(items);

  /// Decodes a selected cart modifier group.
  factory CartModifierGroup.fromJson(Map<String, Object?> json) =>
      CartModifierGroup._fromReader(
        JsonReader.fromObject(json, context: 'cartModifierGroup'),
      );

  factory CartModifierGroup._fromReader(JsonReader reader) => CartModifierGroup(
        id: reader.string('id'),
        name: reader.string('name'),
        rule: ModifierRule.fromJson(reader.object('rule').asMap()),
        items: reader
            .optionalObjectList('items')
            .map(CartModifierItem._fromReader),
      );

  /// Stable modifier-group identifier.
  final String id;

  /// Customer-facing group name.
  final String name;

  /// Selection constraint.
  final ModifierRule rule;

  /// Selected modifier items.
  final List<CartModifierItem> items;
}

/// A selected modifier item stored on a cart item.
final class CartModifierItem {
  /// Creates an immutable selected modifier item.
  CartModifierItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required Iterable<CartModifierGroup> children,
    this.priceFormatted,
  }) : children = List<CartModifierGroup>.unmodifiable(children);

  /// Decodes a selected cart modifier item.
  factory CartModifierItem.fromJson(Map<String, Object?> json) =>
      CartModifierItem._fromReader(
        JsonReader.fromObject(json, context: 'cartModifierItem'),
      );

  factory CartModifierItem._fromReader(JsonReader reader) => CartModifierItem(
        id: reader.string('id'),
        name: reader.string('name'),
        price: reader.string('price'),
        priceFormatted: reader.nullableString('priceFormatted'),
        quantity: reader.integer('quantity'),
        children: reader
            .optionalObjectList('children')
            .map(CartModifierGroup._fromReader),
      );

  /// Stable modifier-item identifier.
  final String id;

  /// Customer-facing option name.
  final String name;

  /// Decimal price adjustment.
  final String price;

  /// Preformatted price adjustment.
  final String? priceFormatted;

  /// Selected quantity.
  final int quantity;

  /// Nested selected groups.
  final List<CartModifierGroup> children;
}

/// Compact product data optionally embedded in a cart item.
final class CartProductSummary {
  /// Creates an immutable product summary.
  const CartProductSummary({required this.id, this.name, this.price});

  /// Decodes an embedded cart product summary.
  factory CartProductSummary.fromJson(Map<String, Object?> json) =>
      CartProductSummary._fromReader(
        JsonReader.fromObject(json, context: 'cartProduct'),
      );

  factory CartProductSummary._fromReader(JsonReader reader) =>
      CartProductSummary(
        id: reader.string('id'),
        name: reader.nullableString('name'),
        price: reader.nullableString('price'),
      );

  /// Stable product identifier.
  final String id;

  /// Customer-facing product name.
  final String? name;

  /// Decimal price string.
  final String? price;
}

/// Fee rates and fixed amounts embedded in a cart response.
final class CartFees {
  /// Creates immutable cart fees.
  const CartFees({
    this.enterpriseFeeRate,
    this.enterpriseFeeFix,
    this.serviceFeeRate,
    this.serviceFeeFix,
    this.taxRate,
    this.tipRate,
    this.fulfillmentMethodFeeFix,
    this.fulfillmentMethodFeeRate,
    this.paymentProcessingFeeRate,
    this.paymentProcessingFeeFix,
  });

  /// Decodes cart fees.
  factory CartFees.fromJson(Map<String, Object?> json) => CartFees._fromReader(
        JsonReader.fromObject(json, context: 'cartFees'),
      );

  factory CartFees._fromReader(JsonReader reader) => CartFees(
        enterpriseFeeRate: reader.nullableString('enterpriseFeeRate'),
        enterpriseFeeFix: reader.nullableString('enterpriseFeeFix'),
        serviceFeeRate: reader.nullableString('serviceFeeRate'),
        serviceFeeFix: reader.nullableString('serviceFeeFix'),
        taxRate: reader.nullableString('taxRate'),
        tipRate: reader.nullableString('tipRate'),
        fulfillmentMethodFeeFix:
            reader.nullableString('fulfillmentMethodFeeFix'),
        fulfillmentMethodFeeRate:
            reader.nullableString('fulfillmentMethodFeeRate'),
        paymentProcessingFeeRate:
            reader.nullableString('paymentProcessingFeeRate'),
        paymentProcessingFeeFix:
            reader.nullableString('paymentProcessingFeeFix'),
      );

  /// Enterprise fee-rate wire value.
  final String? enterpriseFeeRate;

  /// Enterprise fixed-fee wire value.
  final String? enterpriseFeeFix;

  /// Service fee-rate wire value.
  final String? serviceFeeRate;

  /// Service fixed-fee wire value.
  final String? serviceFeeFix;

  /// Tax-rate wire value.
  final String? taxRate;

  /// Tip-rate wire value.
  final String? tipRate;

  /// Fulfillment fixed-fee wire value.
  final String? fulfillmentMethodFeeFix;

  /// Fulfillment fee-rate wire value.
  final String? fulfillmentMethodFeeRate;

  /// Payment-processing fee-rate wire value.
  final String? paymentProcessingFeeRate;

  /// Payment-processing fixed-fee wire value.
  final String? paymentProcessingFeeFix;
}

/// Delivery details embedded in a cart.
final class CartDeliveryInfo {
  /// Creates immutable delivery details.
  const CartDeliveryInfo({required this.addressString, this.address});

  /// Decodes cart delivery details.
  factory CartDeliveryInfo.fromJson(Map<String, Object?> json) =>
      CartDeliveryInfo._fromReader(
        JsonReader.fromObject(json, context: 'cartDeliveryInfo'),
      );

  factory CartDeliveryInfo._fromReader(JsonReader reader) {
    final address = reader.nullableObject('addressData');
    return CartDeliveryInfo(
      addressString: reader.string('addressString'),
      address: address == null ? null : Address.fromJson(address.asMap()),
    );
  }

  /// Customer-facing delivery address.
  final String addressString;

  /// Structured delivery address.
  final Address? address;
}

/// Table details embedded in a cart.
final class CartTableServiceInfo {
  /// Creates immutable table details.
  const CartTableServiceInfo({this.tableNumber});

  /// Decodes cart table-service details.
  factory CartTableServiceInfo.fromJson(Map<String, Object?> json) =>
      CartTableServiceInfo._fromReader(
        JsonReader.fromObject(json, context: 'cartTableServiceInfo'),
      );

  factory CartTableServiceInfo._fromReader(JsonReader reader) =>
      CartTableServiceInfo(tableNumber: reader.nullableString('tableNumber'));

  /// Customer-entered table number.
  final String? tableNumber;
}

/// Room-service details embedded in a cart.
final class CartRoomServiceInfo {
  /// Creates immutable room-service details.
  const CartRoomServiceInfo({this.lastName, this.roomNumber});

  /// Decodes cart room-service details.
  factory CartRoomServiceInfo.fromJson(Map<String, Object?> json) =>
      CartRoomServiceInfo._fromReader(
        JsonReader.fromObject(json, context: 'cartRoomServiceInfo'),
      );

  factory CartRoomServiceInfo._fromReader(JsonReader reader) =>
      CartRoomServiceInfo(
        lastName: reader.nullableString('lastName'),
        roomNumber: reader.nullableString('roomNumber'),
      );

  /// Guest last name.
  final String? lastName;

  /// Room number.
  final String? roomNumber;
}

/// Allowed changes to a cart's fulfillment and timing settings.
final class UpdateCartRequest {
  /// Creates an immutable cart update.
  const UpdateCartRequest({
    this.fulfillmentMethod,
    this.pickupType,
    this.orderTime,
    this.note,
  });

  /// Requested fulfillment method.
  final FulfillmentMethod? fulfillmentMethod;

  /// Requested order timing.
  final OrderTiming? pickupType;

  /// Restaurant-local order time wire value.
  final String? orderTime;

  /// Customer note.
  final String? note;

  /// Serializes only fields accepted by the cart update endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        if (fulfillmentMethod != null)
          'fulfillmentMethod': fulfillmentMethod!.wireValue,
        if (pickupType != null) 'pickupType': pickupType!.wireValue,
        if (orderTime != null) 'orderTime': orderTime,
        if (note != null) 'note': note,
      };
}

/// Contact details used to validate a cart before checkout.
final class ValidateCartCustomerRequest {
  /// Creates validated checkout contact details.
  ValidateCartCustomerRequest({
    required this.customerName,
    this.emailAddress,
    this.phoneNumber,
  }) {
    if (customerName.trim().isEmpty) {
      throw ArgumentError('customerName must not be empty.');
    }
    if (emailAddress == null && phoneNumber == null) {
      throw ArgumentError(
        'Either emailAddress or phoneNumber must be provided.',
      );
    }
  }

  /// Customer display name.
  final String customerName;

  /// Customer email address.
  final String? emailAddress;

  /// Customer phone number.
  final String? phoneNumber;

  /// Serializes only fields accepted by cart validation.
  Map<String, Object?> toJson() => <String, Object?>{
        'customerName': customerName,
        if (emailAddress != null) 'emailAddress': emailAddress,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      };
}

/// A gratuity change request.
final class UpdateGratuityRequest {
  /// Creates an immutable gratuity request.
  const UpdateGratuityRequest({this.amount, this.percentage});

  /// Decimal gratuity amount.
  final String? amount;

  /// Percentage wire value.
  final String? percentage;

  /// Serializes only fields accepted by the gratuity endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        if (amount != null) 'amount': amount,
        if (percentage != null) 'percentage': percentage,
      };
}

/// A delivery-address request for a cart.
final class SetDeliveryRequest {
  /// Creates an immutable delivery request.
  const SetDeliveryRequest({required this.address});

  /// Delivery address.
  final DeliveryAddressRequest address;

  /// Serializes only fields accepted by the delivery endpoint.
  Map<String, Object?> toJson() => address.toJson();
}

/// A table assignment request for a cart.
final class SetTableRequest {
  /// Creates an immutable table request.
  const SetTableRequest({required this.tableNumber});

  /// Customer-entered table number.
  final String tableNumber;

  /// Serializes only fields accepted by the table endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'tableNumber': tableNumber,
      };
}

/// A room-service assignment request for a cart.
final class SetRoomRequest {
  /// Creates an immutable room-service request.
  const SetRoomRequest({required this.lastName, required this.roomNumber});

  /// Guest last name.
  final String lastName;

  /// Room number.
  final String roomNumber;

  /// Serializes only fields accepted by the room-service endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'lastName': lastName,
        'roomNumber': roomNumber,
      };
}

/// An order-time change request.
final class UpdateOrderTimeRequest {
  /// Creates an immutable order-time request.
  const UpdateOrderTimeRequest({
    required this.pickupType,
    this.orderDate,
    this.orderTime,
  });

  /// Requested order timing.
  final OrderTiming pickupType;

  /// Restaurant-local order date wire value.
  final String? orderDate;

  /// Restaurant-local order time wire value.
  final String? orderTime;

  /// Serializes only fields accepted by the order-time endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'pickupType': pickupType.wireValue,
        if (orderDate != null) 'orderDate': orderDate,
        if (orderTime != null) 'orderTime': orderTime,
      };
}

/// A request to add a configured product to a cart.
final class AddCartItemRequest {
  /// Creates a validated add-item request.
  AddCartItemRequest({
    required this.productId,
    required this.quantity,
    required this.itemUnavailableAction,
    required List<SelectedModifierGroup> selections,
    this.specialInstructions,
    this.categoryId,
  }) : selections = List<SelectedModifierGroup>.unmodifiable(selections) {
    if (productId.isEmpty) {
      throw ArgumentError('productId must not be empty.');
    }
    _validateQuantity(quantity);
    if (selections.length > 50) {
      throw ArgumentError('selections must contain at most 50 groups.');
    }
  }

  /// Product identifier.
  final String productId;

  /// Item quantity.
  final int quantity;

  /// Optional customer instructions.
  final String? specialInstructions;

  /// Source menu-category identifier.
  final String? categoryId;

  /// Action to take if the item becomes unavailable.
  final ItemUnavailableAction itemUnavailableAction;

  /// Selected modifier groups.
  final List<SelectedModifierGroup> selections;

  /// Serializes only fields accepted by the add-item endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'productId': productId,
        'quantity': quantity,
        if (specialInstructions != null)
          'specialInstructions': specialInstructions,
        if (categoryId != null) 'categoryId': categoryId,
        'itemUnavailableAction': itemUnavailableAction.wireValue,
        'selections': selections
            .map((selection) => selection.toJson())
            .toList(growable: false),
      };
}

/// A cart-item quantity change request.
final class UpdateCartItemQuantityRequest {
  /// Creates a validated quantity request.
  UpdateCartItemQuantityRequest({required this.quantity}) {
    if (quantity < 0 || quantity > 99) {
      throw ArgumentError('quantity must be between 0 and 99.');
    }
  }

  /// New item quantity. Zero removes the item when accepted by the API.
  final int quantity;

  /// Serializes only fields accepted by the quantity endpoint.
  Map<String, Object?> toJson() => <String, Object?>{'quantity': quantity};
}

/// A discount-code application request.
final class ApplyDiscountRequest {
  /// Creates an immutable discount request.
  const ApplyDiscountRequest({required this.code});

  /// Customer-entered discount code.
  final String code;

  /// Serializes only fields accepted by the discount endpoint.
  Map<String, Object?> toJson() => <String, Object?>{'code': code};
}

void _validateQuantity(int quantity) {
  if (quantity < 1 || quantity > 99) {
    throw ArgumentError('quantity must be between 1 and 99.');
  }
}
