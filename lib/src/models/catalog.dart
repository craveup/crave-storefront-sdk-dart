import '../json/json_reader.dart';

/// A location's menus and popular products.
final class MenuBundle {
  /// Creates an immutable menu bundle.
  const MenuBundle({required this.menus, required this.popularProducts});

  /// Decodes a menu-bundle response.
  factory MenuBundle.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'menuBundle');
    return MenuBundle(
      menus: List<Menu>.unmodifiable(
        reader.optionalObjectList('menus').map(Menu.fromReader),
      ),
      popularProducts: List<MenuProduct>.unmodifiable(
        reader
            .optionalObjectList('popularProducts')
            .map(MenuProduct.fromReader),
      ),
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
  const Menu({
    required this.id,
    required this.name,
    required this.isActive,
    required this.time,
    required this.categories,
    this.imageUrl,
  });

  /// Decodes a menu from an existing reader.
  factory Menu.fromReader(JsonReader reader) => Menu(
        id: reader.string('id'),
        name: reader.string('name'),
        isActive: reader.boolean('isActive'),
        time: reader.string('time'),
        imageUrl: reader.nullableString('imageUrl'),
        categories: List<MenuCategory>.unmodifiable(
          reader.optionalObjectList('categories').map(MenuCategory.fromReader),
        ),
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
  const MenuCategory({
    required this.id,
    required this.name,
    required this.products,
  });

  /// Decodes a category from an existing reader.
  factory MenuCategory.fromReader(JsonReader reader) => MenuCategory(
        id: reader.string('id'),
        name: reader.string('name'),
        products: List<MenuProduct>.unmodifiable(
          reader.optionalObjectList('products').map(MenuProduct.fromReader),
        ),
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
  const MenuProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.displayPrice,
    required this.currency,
    required this.modifierIds,
    required this.images,
    this.description,
    this.availability,
    this.nutrition,
  });

  /// Decodes a menu product from an existing reader.
  factory MenuProduct.fromReader(JsonReader reader) {
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
          : Nutrition.fromReader(nutritionReader),
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
  const Product({
    required this.id,
    required this.locationId,
    required this.name,
    required this.price,
    required this.displayPrice,
    required this.currency,
    required this.modifierIds,
    required this.images,
    required this.modifiers,
    this.description,
    this.availability,
    this.nutrition,
  });

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
      modifiers: List<ModifierGroup>.unmodifiable(
        reader.optionalObjectList('modifiers').map(ModifierGroup.fromReader),
      ),
      nutrition: nutritionReader == null
          ? null
          : Nutrition.fromReader(nutritionReader),
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
  const CartRecommendation({
    required this.id,
    required this.name,
    required this.price,
    required this.images,
    required this.modifierIds,
    this.description,
    this.availability,
  });

  /// Decodes a cart-recommendation response item.
  factory CartRecommendation.fromJson(Map<String, Object?> json) =>
      CartRecommendation.fromReader(
        JsonReader.fromObject(json, context: 'cartRecommendation'),
      );

  /// Decodes a recommendation from an existing reader.
  factory CartRecommendation.fromReader(JsonReader reader) =>
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
  const Nutrition({
    required this.dietaryPreferences,
    required this.ingredients,
    this.calorieCount,
  });

  /// Decodes nutrition information from an existing reader.
  factory Nutrition.fromReader(JsonReader reader) => Nutrition(
        calorieCount: reader.nullableInteger('calorieCount'),
        dietaryPreferences: reader.optionalStringList('dietaryPreferences'),
        ingredients: reader.optionalStringList('ingredients'),
      );

  /// Optional calorie count.
  final int? calorieCount;

  /// Dietary preference labels.
  final List<String> dietaryPreferences;

  /// Ingredient labels.
  final List<String> ingredients;
}

/// A product modifier group.
final class ModifierGroup {
  /// Creates an immutable modifier group.
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.rule,
    required this.items,
    this.description,
    this.imageUrl,
  });

  /// Decodes a modifier group from an existing reader.
  factory ModifierGroup.fromReader(JsonReader reader) => ModifierGroup(
        id: reader.string('id'),
        name: reader.string('name'),
        description: reader.nullableString('description'),
        imageUrl: reader.nullableString('imageUrl'),
        rule: ModifierRule.fromReader(reader.object('rule')),
        items: List<ModifierItem>.unmodifiable(
          reader.optionalObjectList('items').map(ModifierItem.fromReader),
        ),
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

  /// Decodes a modifier rule from an existing reader.
  factory ModifierRule.fromReader(JsonReader reader) => ModifierRule(
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
  const ModifierItem({
    required this.id,
    required this.name,
    required this.price,
    required this.maxQuantity,
    required this.childGroups,
  });

  /// Decodes a modifier item from an existing reader.
  factory ModifierItem.fromReader(JsonReader reader) => ModifierItem(
        id: reader.string('id'),
        name: reader.string('name'),
        price: reader.string('price'),
        maxQuantity: reader.integer('maxQuantity'),
        childGroups: List<ModifierChildLink>.unmodifiable(
          reader
              .optionalObjectList('childGroups')
              .map(ModifierChildLink.fromReader),
        ),
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

  /// Decodes a child-group link from an existing reader.
  factory ModifierChildLink.fromReader(JsonReader reader) {
    final overrides = reader.nullableObject('overrides');
    final group = reader.nullableObject('group');
    return ModifierChildLink(
      groupId: reader.string('groupId'),
      minimumOverride: overrides?.nullableInteger('min'),
      maximumOverride: overrides?.nullableInteger('max'),
      applyPerParentQuantity: reader.nullableBoolean('applyPerParentQuantity'),
      group: group == null ? null : ModifierGroup.fromReader(group),
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
