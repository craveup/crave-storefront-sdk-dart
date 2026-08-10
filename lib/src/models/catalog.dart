import '../json/json_reader.dart';

/// A location's menus and popular products.
final class MenuBundle {
  /// Creates an immutable menu bundle.
  MenuBundle({
    required Iterable<Menu> menus,
    required Iterable<MenuProduct> popularProducts,
  })  : menus = List<Menu>.unmodifiable(menus),
        popularProducts = List<MenuProduct>.unmodifiable(popularProducts);

  /// Decodes a menu-bundle response.
  factory MenuBundle.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'menuBundle');
    return MenuBundle(
      menus: reader.optionalObjectList('menus').map(Menu._fromReader),
      popularProducts: reader
          .optionalObjectList('popularProducts')
          .map(MenuProduct._fromReader),
    );
  }

  /// Published menus.
  final List<Menu> menus;

  /// Popular products selected by the location.
  final List<MenuProduct> popularProducts;
}

/// A published menu.
final class Menu {
  /// Creates an immutable menu.
  Menu({
    required this.id,
    required this.name,
    required this.isActive,
    required this.time,
    required Iterable<MenuCategory> categories,
    this.imageUrl,
  }) : categories = List<MenuCategory>.unmodifiable(categories);

  /// Decodes a menu response.
  factory Menu.fromJson(Map<String, Object?> json) => Menu._fromReader(
        JsonReader.fromObject(json, context: 'menu'),
      );

  factory Menu._fromReader(JsonReader reader) => Menu(
        id: reader.string('id'),
        name: reader.string('name'),
        isActive: reader.boolean('isActive'),
        time: reader.string('time'),
        imageUrl: reader.nullableString('imageUrl'),
        categories: reader
            .optionalObjectList('categories')
            .map(MenuCategory._fromReader),
      );

  /// Stable menu identifier.
  final String id;

  /// Customer-facing menu name.
  final String name;

  /// Whether the menu is active.
  final bool isActive;

  /// Restaurant-local availability label or wire value.
  final String time;

  /// Optional menu-image URL.
  final String? imageUrl;

  /// Product categories in display order.
  final List<MenuCategory> categories;
}

/// A category in a published menu.
final class MenuCategory {
  /// Creates an immutable category.
  MenuCategory({
    required this.id,
    required this.name,
    required Iterable<MenuProduct> products,
  }) : products = List<MenuProduct>.unmodifiable(products);

  /// Decodes a menu-category response.
  factory MenuCategory.fromJson(Map<String, Object?> json) =>
      MenuCategory._fromReader(
        JsonReader.fromObject(json, context: 'menuCategory'),
      );

  factory MenuCategory._fromReader(JsonReader reader) => MenuCategory(
        id: reader.string('id'),
        name: reader.string('name'),
        products:
            reader.optionalObjectList('products').map(MenuProduct._fromReader),
      );

  /// Stable category identifier.
  final String id;

  /// Customer-facing category name.
  final String name;

  /// Products in display order.
  final List<MenuProduct> products;
}

/// A compact product embedded in a menu.
final class MenuProduct {
  /// Creates an immutable menu product.
  MenuProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.displayPrice,
    required this.currency,
    required Iterable<String> modifierIds,
    required Iterable<String> images,
    this.description,
    this.availability,
    this.nutrition,
  })  : modifierIds = List<String>.unmodifiable(modifierIds),
        images = List<String>.unmodifiable(images);

  /// Decodes a menu-product response.
  factory MenuProduct.fromJson(Map<String, Object?> json) =>
      MenuProduct._fromReader(
        JsonReader.fromObject(json, context: 'menuProduct'),
      );

  factory MenuProduct._fromReader(JsonReader reader) {
    final nutritionReader = reader.nullableObject('nutrition');
    return MenuProduct(
      id: reader.string('id'),
      name: reader.string('name'),
      price: reader.string('price'),
      displayPrice: reader.string('displayPrice'),
      currency: reader.string('currency'),
      modifierIds: reader.optionalStringList('modifierIds'),
      description: reader.nullableString('description'),
      availability: reader.nullableString('availability'),
      images: reader.optionalStringList('images'),
      nutrition: nutritionReader == null
          ? null
          : Nutrition._fromReader(nutritionReader),
    );
  }

  /// Stable product identifier.
  final String id;

  /// Customer-facing product name.
  final String name;

  /// Decimal price string.
  final String price;

  /// Preformatted price.
  final String displayPrice;

  /// Currency wire value, including values added by the API later.
  final String currency;

  /// Modifier-group identifiers.
  final List<String> modifierIds;

  /// Optional product description.
  final String? description;

  /// Availability wire value.
  final String? availability;

  /// Product image URLs.
  final List<String> images;

  /// Optional nutrition details.
  final Nutrition? nutrition;
}

/// Full product details returned by the product endpoint.
final class Product {
  /// Creates immutable product details.
  Product({
    required this.id,
    required this.locationId,
    required this.name,
    required this.price,
    required this.displayPrice,
    required this.currency,
    required Iterable<String> modifierIds,
    required Iterable<String> images,
    required Iterable<ModifierGroup> modifiers,
    this.description,
    this.availability,
    this.nutrition,
  })  : modifierIds = List<String>.unmodifiable(modifierIds),
        images = List<String>.unmodifiable(images),
        modifiers = List<ModifierGroup>.unmodifiable(modifiers);

  /// Decodes a product response.
  factory Product.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'product');
    final nutritionReader = reader.nullableObject('nutrition');
    return Product(
      id: reader.string('id'),
      locationId: reader.string('locationId'),
      name: reader.string('name'),
      price: reader.string('price'),
      displayPrice: reader.string('displayPrice'),
      currency: reader.string('currency'),
      modifierIds: reader.optionalStringList('modifierIds'),
      description: reader.nullableString('description'),
      availability: reader.nullableString('availability'),
      images: reader.optionalStringList('images'),
      modifiers:
          reader.optionalObjectList('modifiers').map(ModifierGroup._fromReader),
      nutrition: nutritionReader == null
          ? null
          : Nutrition._fromReader(nutritionReader),
    );
  }

  /// Stable product identifier.
  final String id;

  /// Owning location identifier.
  final String locationId;

  /// Customer-facing product name.
  final String name;

  /// Decimal price string.
  final String price;

  /// Preformatted price.
  final String displayPrice;

  /// Currency wire value, including future values.
  final String currency;

  /// Modifier-group identifiers.
  final List<String> modifierIds;

  /// Optional product description.
  final String? description;

  /// Availability wire value.
  final String? availability;

  /// Product image URLs.
  final List<String> images;

  /// Resolved modifier groups.
  final List<ModifierGroup> modifiers;

  /// Optional nutrition details.
  final Nutrition? nutrition;
}

/// A compact product returned as a cart recommendation.
final class CartRecommendation {
  /// Creates an immutable cart recommendation.
  CartRecommendation({
    required this.id,
    required this.name,
    required this.price,
    required Iterable<String> images,
    required Iterable<String> modifierIds,
    this.description,
    this.availability,
  })  : images = List<String>.unmodifiable(images),
        modifierIds = List<String>.unmodifiable(modifierIds);

  /// Decodes a cart-recommendation response item.
  factory CartRecommendation.fromJson(Map<String, Object?> json) =>
      CartRecommendation._fromReader(
        JsonReader.fromObject(json, context: 'cartRecommendation'),
      );

  factory CartRecommendation._fromReader(JsonReader reader) =>
      CartRecommendation(
        id: reader.string('id'),
        name: reader.string('name'),
        price: reader.string('price'),
        description: reader.nullableString('description'),
        availability: reader.nullableString('availability'),
        images: reader.optionalStringList('images'),
        modifierIds: reader.optionalStringList('modifierIds'),
      );

  /// Stable product identifier.
  final String id;

  /// Customer-facing product name.
  final String name;

  /// Decimal price string.
  final String price;

  /// Optional product description.
  final String? description;

  /// Availability wire value.
  final String? availability;

  /// Product image URLs.
  final List<String> images;

  /// Modifier-group identifiers needed to configure the product.
  final List<String> modifierIds;
}

/// Product nutrition information.
final class Nutrition {
  /// Creates immutable nutrition information.
  Nutrition({
    required Iterable<String> dietaryPreferences,
    required Iterable<String> ingredients,
    this.calorieCount,
  })  : dietaryPreferences = List<String>.unmodifiable(dietaryPreferences),
        ingredients = List<String>.unmodifiable(ingredients);

  /// Decodes product nutrition information.
  factory Nutrition.fromJson(Map<String, Object?> json) =>
      Nutrition._fromReader(
        JsonReader.fromObject(json, context: 'nutrition'),
      );

  factory Nutrition._fromReader(JsonReader reader) => Nutrition(
        calorieCount: reader.nullableNumber('calorieCount'),
        dietaryPreferences: reader.optionalStringList('dietaryPreferences'),
        ingredients: reader.optionalStringList('ingredients'),
      );

  /// Optional finite calorie count.
  final double? calorieCount;

  /// Dietary preference labels.
  final List<String> dietaryPreferences;

  /// Ingredient labels.
  final List<String> ingredients;
}

/// A product modifier group.
final class ModifierGroup {
  /// Creates an immutable modifier group.
  ModifierGroup({
    required this.id,
    required this.name,
    required this.rule,
    required Iterable<ModifierItem> items,
    this.description,
    this.imageUrl,
  }) : items = List<ModifierItem>.unmodifiable(items);

  /// Decodes a modifier-group response.
  factory ModifierGroup.fromJson(Map<String, Object?> json) =>
      ModifierGroup._fromReader(
        JsonReader.fromObject(json, context: 'modifierGroup'),
      );

  factory ModifierGroup._fromReader(JsonReader reader) => ModifierGroup(
        id: reader.string('id'),
        name: reader.string('name'),
        description: reader.nullableString('description'),
        imageUrl: reader.nullableString('imageUrl'),
        rule: ModifierRule._fromReader(reader.object('rule')),
        items: reader.optionalObjectList('items').map(ModifierItem._fromReader),
      );

  /// Stable modifier-group identifier.
  final String id;

  /// Customer-facing group name.
  final String name;

  /// Optional group description.
  final String? description;

  /// Optional customer-facing group image URL.
  final String? imageUrl;

  /// Selection constraint.
  final ModifierRule rule;

  /// Selectable options.
  final List<ModifierItem> items;
}

/// Minimum and maximum selection constraint for a modifier group.
final class ModifierRule {
  /// Creates an immutable modifier rule.
  const ModifierRule({required this.minimum, required this.maximum});

  /// Decodes a modifier selection rule.
  factory ModifierRule.fromJson(Map<String, Object?> json) =>
      ModifierRule._fromReader(
        JsonReader.fromObject(json, context: 'modifierRule'),
      );

  factory ModifierRule._fromReader(JsonReader reader) => ModifierRule(
        minimum: reader.integer('min'),
        maximum: reader.integer('max'),
      );

  /// Minimum number of selections.
  final int minimum;

  /// Maximum number of selections.
  final int maximum;
}

/// One selectable modifier option.
final class ModifierItem {
  /// Creates an immutable modifier item.
  ModifierItem({
    required this.id,
    required this.name,
    required this.price,
    required this.maxQuantity,
    required Iterable<ModifierChildLink> childGroups,
  }) : childGroups = List<ModifierChildLink>.unmodifiable(childGroups);

  /// Decodes a modifier-item response.
  factory ModifierItem.fromJson(Map<String, Object?> json) =>
      ModifierItem._fromReader(
        JsonReader.fromObject(json, context: 'modifierItem'),
      );

  factory ModifierItem._fromReader(JsonReader reader) => ModifierItem(
        id: reader.string('id'),
        name: reader.string('name'),
        price: reader.string('price'),
        maxQuantity: reader.integer('maxQuantity'),
        childGroups: reader
            .optionalObjectList('childGroups')
            .map(ModifierChildLink._fromReader),
      );

  /// Stable option identifier.
  final String id;

  /// Customer-facing option name.
  final String name;

  /// Decimal price adjustment.
  final String price;

  /// Maximum selectable quantity.
  final int maxQuantity;

  /// Links to conditional child groups.
  final List<ModifierChildLink> childGroups;
}

/// A conditional link from a modifier option to a child group.
final class ModifierChildLink {
  /// Creates an immutable child-group link.
  const ModifierChildLink({
    required this.groupId,
    this.minimumOverride,
    this.maximumOverride,
    this.applyPerParentQuantity,
    this.group,
    this.circular,
  });

  /// Decodes a modifier child-group link.
  factory ModifierChildLink.fromJson(Map<String, Object?> json) =>
      ModifierChildLink._fromReader(
        JsonReader.fromObject(json, context: 'modifierChildLink'),
      );

  factory ModifierChildLink._fromReader(JsonReader reader) {
    final overrides = reader.nullableObject('overrides');
    final group = reader.nullableObject('group');
    return ModifierChildLink(
      groupId: reader.string('groupId'),
      minimumOverride: overrides?.nullableInteger('min'),
      maximumOverride: overrides?.nullableInteger('max'),
      applyPerParentQuantity: reader.nullableBoolean('applyPerParentQuantity'),
      group: group == null ? null : ModifierGroup._fromReader(group),
      circular: reader.nullableBoolean('circular'),
    );
  }

  /// Referenced modifier-group identifier.
  final String groupId;

  /// Optional minimum-selection override.
  final int? minimumOverride;

  /// Optional maximum-selection override.
  final int? maximumOverride;

  /// Whether the child constraint applies per parent quantity.
  final bool? applyPerParentQuantity;

  /// Resolved child group when embedded by the API.
  final ModifierGroup? group;

  /// Whether the server detected a circular group reference.
  final bool? circular;
}

/// A selected modifier group in an add-item request.
final class SelectedModifierGroup {
  /// Creates a selected modifier group.
  SelectedModifierGroup({
    required this.groupId,
    required List<SelectedModifierOption> selectedOptions,
  }) : selectedOptions = List<SelectedModifierOption>.unmodifiable(
          selectedOptions,
        ) {
    if (groupId.isEmpty) {
      throw ArgumentError('groupId must not be empty.');
    }
    if (selectedOptions.isEmpty || selectedOptions.length > 50) {
      throw ArgumentError(
        'selectedOptions must contain between 1 and 50 options.',
      );
    }
  }

  /// Modifier-group identifier.
  final String groupId;

  /// Selected options in this group.
  final List<SelectedModifierOption> selectedOptions;

  /// Serializes only fields accepted by the add-item endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'groupId': groupId,
        'selectedOptions': selectedOptions
            .map((option) => option.toJson())
            .toList(growable: false),
      };
}

/// A selected modifier option in an add-item request.
final class SelectedModifierOption {
  /// Creates a selected modifier option.
  SelectedModifierOption({
    required this.optionId,
    required this.quantity,
    List<SelectedModifierGroup> children = const <SelectedModifierGroup>[],
  }) : children = List<SelectedModifierGroup>.unmodifiable(children) {
    if (optionId.isEmpty) {
      throw ArgumentError('optionId must not be empty.');
    }
    if (quantity < 1 || quantity > 99) {
      throw ArgumentError('quantity must be between 1 and 99.');
    }
    if (children.length > 20) {
      throw ArgumentError('children must contain at most 20 groups.');
    }
  }

  /// Modifier-option identifier.
  final String optionId;

  /// Selected quantity.
  final int quantity;

  /// Nested selected child groups.
  final List<SelectedModifierGroup> children;

  /// Serializes only fields accepted by the add-item endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'optionId': optionId,
        'quantity': quantity,
        if (children.isNotEmpty)
          'children':
              children.map((child) => child.toJson()).toList(growable: false),
      };
}
