import '../origin.dart';

/// Unambiguous storage boundary for one merchant location.
final class StorefrontSessionScope {
  /// Creates an API-origin, merchant, and location storage scope.
  StorefrontSessionScope({
    required Uri apiOrigin,
    required this.merchantSlug,
    required this.locationId,
  }) : apiOrigin = normalizeStorefrontOrigin(apiOrigin) {
    if (merchantSlug.trim().isEmpty) {
      throw ArgumentError('merchantSlug must not be empty.');
    }
    if (locationId.trim().isEmpty) {
      throw ArgumentError('locationId must not be empty.');
    }
  }

  /// Canonical Storefront API origin.
  final Uri apiOrigin;

  /// Canonical merchant slug.
  final String merchantSlug;

  /// Location identifier owned by the merchant.
  final String locationId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorefrontSessionScope &&
          apiOrigin == other.apiOrigin &&
          merchantSlug == other.merchantSlug &&
          locationId == other.locationId;

  @override
  int get hashCode => Object.hash(apiOrigin, merchantSlug, locationId);

  @override
  String toString() => 'StorefrontSessionScope(redacted)';
}

/// Persistable guest-cart recovery state.
final class StorefrontCartSession {
  /// Creates an immutable cart session.
  StorefrontCartSession({
    required this.scope,
    required this.cartId,
    required this.revision,
    this.accessToken,
    this.expiresAt,
  }) {
    if (cartId.trim().isEmpty) {
      throw ArgumentError('cartId must not be empty.');
    }
    if (revision < 0) {
      throw ArgumentError('revision must not be negative.');
    }
    if (accessToken != null && accessToken!.trim().isEmpty) {
      throw ArgumentError('accessToken must be null or non-empty.');
    }
  }

  /// Storage boundary for this session.
  final StorefrontSessionScope scope;

  /// Current cart identifier.
  final String cartId;

  /// Guest cart capability. Production adapters should encrypt this value.
  final String? accessToken;

  /// Latest known cart revision.
  final int revision;

  /// Server-declared cart expiry when available.
  final DateTime? expiresAt;

  /// Returns the same session with [nextRevision].
  StorefrontCartSession withRevision(int nextRevision) => StorefrontCartSession(
        scope: scope,
        cartId: cartId,
        accessToken: accessToken,
        revision: nextRevision,
        expiresAt: expiresAt,
      );

  /// Returns the same session without its guest capability.
  StorefrontCartSession withoutAccessToken() => StorefrontCartSession(
        scope: scope,
        cartId: cartId,
        revision: revision,
        expiresAt: expiresAt,
      );

  @override
  String toString() => 'StorefrontCartSession(revision: $revision, '
      'hasAccessToken: ${accessToken != null})';
}
