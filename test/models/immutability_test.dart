import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';
import 'package:test/test.dart';

void main() {
  test('catalog response constructors defensively copy collection inputs', () {
    final modifierIds = <String>['modifier-1'];
    final images = <String>['https://cdn.example.test/product.png'];
    final menuProduct = MenuProduct(
      id: 'product-1',
      name: 'Tea',
      price: '4.00',
      displayPrice: r'$4.00',
      currency: 'usd',
      modifierIds: modifierIds,
      images: images,
    );
    _expectUnmodifiableCopy(modifierIds, menuProduct.modifierIds);
    _expectUnmodifiableCopy(images, menuProduct.images);

    final products = <MenuProduct>[menuProduct];
    final category = MenuCategory(
      id: 'category-1',
      name: 'Tea',
      products: products,
    );
    _expectUnmodifiableCopy(products, category.products);

    final categories = <MenuCategory>[category];
    final menu = Menu(
      id: 'menu-1',
      name: 'Main',
      isActive: true,
      time: 'all_day',
      categories: categories,
    );
    _expectUnmodifiableCopy(categories, menu.categories);

    final menus = <Menu>[menu];
    final popularProducts = <MenuProduct>[menuProduct];
    final bundle = MenuBundle(
      menus: menus,
      popularProducts: popularProducts,
    );
    _expectUnmodifiableCopy(menus, bundle.menus);
    _expectUnmodifiableCopy(popularProducts, bundle.popularProducts);

    final childGroups = <ModifierChildLink>[
      const ModifierChildLink(groupId: 'child-group-1'),
    ];
    final modifierItem = ModifierItem(
      id: 'option-1',
      name: 'Large',
      price: '1.00',
      maxQuantity: 1,
      childGroups: childGroups,
    );
    _expectUnmodifiableCopy(childGroups, modifierItem.childGroups);

    final modifierItems = <ModifierItem>[modifierItem];
    final modifierGroup = ModifierGroup(
      id: 'modifier-1',
      name: 'Size',
      rule: const ModifierRule(minimum: 1, maximum: 1),
      items: modifierItems,
    );
    _expectUnmodifiableCopy(modifierItems, modifierGroup.items);

    final productModifierIds = <String>['modifier-1'];
    final productImages = <String>['https://cdn.example.test/product.png'];
    final productModifiers = <ModifierGroup>[modifierGroup];
    final product = Product(
      id: 'product-1',
      locationId: 'location-1',
      name: 'Tea',
      price: '4.00',
      displayPrice: r'$4.00',
      currency: 'usd',
      modifierIds: productModifierIds,
      images: productImages,
      modifiers: productModifiers,
    );
    _expectUnmodifiableCopy(productModifierIds, product.modifierIds);
    _expectUnmodifiableCopy(productImages, product.images);
    _expectUnmodifiableCopy(productModifiers, product.modifiers);

    final recommendationImages = <String>['recommendation.png'];
    final recommendationModifierIds = <String>['modifier-1'];
    final recommendation = CartRecommendation(
      id: 'product-1',
      name: 'Tea',
      price: '4.00',
      images: recommendationImages,
      modifierIds: recommendationModifierIds,
    );
    _expectUnmodifiableCopy(recommendationImages, recommendation.images);
    _expectUnmodifiableCopy(
      recommendationModifierIds,
      recommendation.modifierIds,
    );

    final dietaryPreferences = <String>['vegan'];
    final ingredients = <String>['tea'];
    final nutrition = Nutrition(
      dietaryPreferences: dietaryPreferences,
      ingredients: ingredients,
    );
    _expectUnmodifiableCopy(
      dietaryPreferences,
      nutrition.dietaryPreferences,
    );
    _expectUnmodifiableCopy(ingredients, nutrition.ingredients);
  });

  test('cart response constructor deeply freezes caller-owned state', () {
    final children = <CartModifierGroup>[
      CartModifierGroup(
        id: 'child-group-1',
        name: 'Milk',
        rule: const ModifierRule(minimum: 0, maximum: 1),
        items: const <CartModifierItem>[],
      ),
    ];
    final modifierItem = CartModifierItem(
      id: 'option-1',
      name: 'Large',
      price: '1.00',
      quantity: 1,
      children: children,
    );
    _expectUnmodifiableCopy(children, modifierItem.children);

    final modifierItems = <CartModifierItem>[modifierItem];
    final modifierGroup = CartModifierGroup(
      id: 'group-1',
      name: 'Size',
      rule: const ModifierRule(minimum: 1, maximum: 1),
      items: modifierItems,
    );
    _expectUnmodifiableCopy(modifierItems, modifierGroup.items);

    final selections = <CartModifierGroup>[modifierGroup];
    final item = CartItem(
      id: 'item-1',
      productId: 'product-1',
      name: 'Tea',
      price: '4.00',
      quantity: 1,
      total: '4.00',
      itemUnavailableAction: 'remove_item',
      selections: selections,
    );
    _expectUnmodifiableCopy(selections, item.selections);

    final items = <CartItem>[item];
    final nestedMetadata = <Object?>['mobile'];
    final metadata = <String, Object?>{'channels': nestedMetadata};
    final cart = StorefrontCart(
      id: 'cart-1',
      locationId: 'location-1',
      status: 'open',
      revision: 1,
      fulfilmentMethod: 'takeout',
      totalQuantity: 1,
      items: items,
      metadata: metadata,
    );

    _expectUnmodifiableCopy(items, cart.items);
    metadata['new'] = true;
    nestedMetadata.add('web');
    expect(cart.metadata, <String, Object?>{
      'channels': <Object?>['mobile'],
    });
    expect(
      () => cart.metadata!['new'] = true,
      throwsUnsupportedError,
    );
    expect(
      () => (cart.metadata!['channels']! as List<Object?>).add('web'),
      throwsUnsupportedError,
    );
  });

  test('other response families defensively copy collection inputs', () {
    final pageItems = <String>['first'];
    final page = CursorPage<String>(items: pageItems, nextCursor: null);
    _expectUnmodifiableCopy(pageItems, page.items);

    final locations = <MerchantLocation>[
      const MerchantLocation(
        id: 'location-1',
        restaurantDisplayName: 'Example',
        addressString: '100 Example Street',
        methods: MerchantFulfillmentMethods(
          pickup: true,
          table: false,
          delivery: true,
          roomService: false,
        ),
      ),
    ];
    final merchant = Merchant(
      id: 'merchant-1',
      name: 'Example',
      country: 'US',
      currency: 'usd',
      locations: locations,
    );
    _expectUnmodifiableCopy(locations, merchant.locations);

    final intervals = <String>['12:00'];
    final day =
        OrderDay(value: '2026-08-10', label: 'Today', intervals: intervals);
    _expectUnmodifiableCopy(intervals, day.intervals);
    final days = <OrderDay>[day];
    final times = OrderTimes(orderDays: days, scheduleAllowed: true);
    _expectUnmodifiableCopy(days, times.orderDays);
    final tipPercentages = <String>['15'];
    final gratuity = GratuityConfiguration(
      enabled: true,
      shouldAllowCustomTip: true,
      tipPercentages: tipPercentages,
      defaultTipPercentage: '15',
    );
    _expectUnmodifiableCopy(tipPercentages, gratuity.tipPercentages);

    final unavailableReasons = <String>['insufficient_points'];
    final reward = LoyaltyReward(
      id: 'reward-1',
      name: 'Free Tea',
      status: 'unavailable',
      unavailableReasons: unavailableReasons,
      pointsCost: 100,
      redeemable: false,
    );
    _expectUnmodifiableCopy(unavailableReasons, reward.unavailableReasons);
    final rewards = <LoyaltyReward>[reward];
    final quote = LoyaltyQuote(enabled: true, rewards: rewards);
    _expectUnmodifiableCopy(rewards, quote.rewards);

    final balances = <LoyaltyLedgerBalance>[
      const LoyaltyLedgerBalance(
        unit: 'points',
        posted: 100,
        reserved: 0,
        available: 100,
        asOf: '2026-08-10T00:00:00Z',
      ),
    ];
    final entries = <LoyaltyLedgerEntry>[
      const LoyaltyLedgerEntry(
        operation: 'earn',
        amount: 100,
        unit: 'points',
        occurredAt: '2026-08-10T00:00:00Z',
      ),
    ];
    final ledger = LoyaltyLedger(
      enabled: true,
      balances: balances,
      entries: entries,
    );
    _expectUnmodifiableCopy(balances, ledger.balances);
    _expectUnmodifiableCopy(entries, ledger.entries);

    final claims = <LoyaltyClaim>[
      const LoyaltyClaim(
        claimId: 'claim-1',
        status: 'submitted',
        submittedAt: '2026-08-10T00:00:00Z',
        reason: 'missing_points',
        updatedAt: '2026-08-10T00:00:00Z',
      ),
    ];
    final loyaltyClaims = LoyaltyClaims(claims: claims);
    _expectUnmodifiableCopy(claims, loyaltyClaims.claims);

    final modifiers = <PublicOrderModifier>[
      const PublicOrderModifier(
        groupName: 'Size',
        name: 'Large',
        quantity: 1,
        price: '1.00',
      ),
    ];
    final orderItem = PublicOrderItem(
      id: 'item-1',
      name: 'Tea',
      quantity: 1,
      price: '4.00',
      total: '5.00',
      discount: '0.00',
      specialInstructions: '',
      modifiers: modifiers,
    );
    _expectUnmodifiableCopy(modifiers, orderItem.modifiers);

    final orderItems = <PublicOrderItem>[orderItem];
    final order = PublicOrderDetail(
      id: 'order-1',
      shortId: '1001',
      restaurantDisplayName: 'Example',
      fulfillmentMethod: 'takeout',
      fulfillmentIdentifier: 'pickup',
      pickupType: 'asap',
      orderTime: '12:00',
      orderDate: '2026-08-10',
      totalQuantity: 1,
      currency: 'usd',
      orderTotal: '5.00',
      status: 'received',
      createdAt: '2026-08-10T00:00:00Z',
      partiallyRefunded: false,
      items: orderItems,
      pricing: _pricing(),
    );
    _expectUnmodifiableCopy(orderItems, order.items);
  });
}

PublicOrderPricing _pricing() => const PublicOrderPricing(
      subtotal: '5.00',
      discount: '0.00',
      tax: '0.00',
      tip: '0.00',
      serviceFee: '0.00',
      fulfillmentFee: '0.00',
      enterpriseFee: '0.00',
      total: '5.00',
      refunded: '0.00',
      netPaid: '5.00',
    );

void _expectUnmodifiableCopy<T>(List<T> source, List<T> actual) {
  final expected = List<T>.of(actual);
  source.clear();
  expect(actual, expected);
  expect(() => actual[0] = actual[0], throwsUnsupportedError);
}
