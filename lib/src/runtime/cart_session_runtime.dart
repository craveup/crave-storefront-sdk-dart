import '../session/session.dart';
import '../session/session_store.dart';
import 'request_runtime.dart';

/// Session-derived inputs for one cart request.
final class CartRequestContext {
  const CartRequestContext({
    required this.scope,
    this.accessToken,
    this.revision,
    this.idempotencyKey,
  });

  /// Exact origin, merchant, and location storage boundary.
  final StorefrontSessionScope scope;

  /// Matching guest cart capability, when available.
  final String? accessToken;

  /// Revision selected from caller options or matching stored state.
  final int? revision;

  /// Stable key selected once for an idempotent request.
  final String? idempotencyKey;
}

/// Central owner of cart capability, revision, and request-key lifecycle.
final class CartSessionRuntime {
  /// Creates a cart session runtime.
  const CartSessionRuntime({
    required this.apiOrigin,
    required this.merchantSlug,
    required this.sessionStore,
    required this.idempotencyKeyGenerator,
  });

  /// Canonical API origin.
  final Uri apiOrigin;

  /// Canonical merchant slug.
  final String merchantSlug;

  /// Caller-owned storage adapter.
  final StorefrontSessionStore sessionStore;

  /// Cryptographically secure idempotency-key generator.
  final StorefrontIdempotencyKeyGenerator idempotencyKeyGenerator;

  /// Returns the isolated storage scope for [locationId].
  StorefrontSessionScope scopeFor(String locationId) => StorefrontSessionScope(
        apiOrigin: apiOrigin,
        merchantSlug: merchantSlug,
        locationId: locationId,
      );

  /// Selects capability, revision, and idempotency data for a cart call.
  Future<CartRequestContext> contextFor({
    required String locationId,
    required String cartId,
    required bool idempotent,
    required bool revisionRequired,
    StorefrontRequestOptions? options,
  }) async {
    final scope = scopeFor(locationId);
    final stored = await sessionStore.read(scope);
    final matching = stored?.cartId == cartId ? stored : null;
    return CartRequestContext(
      scope: scope,
      accessToken: matching?.accessToken,
      revision:
          revisionRequired ? options?.revision ?? matching?.revision : null,
      idempotencyKey: idempotent
          ? options?.idempotencyKey ?? idempotencyKeyGenerator.next()
          : null,
    );
  }

  /// Captures the exact cart identity returned by ordering or handoff exchange.
  Future<void> capture({
    required String locationId,
    required String cartId,
    required int revision,
    String? accessToken,
    DateTime? expiresAt,
  }) async {
    final scope = scopeFor(locationId);
    final existing = await sessionStore.read(scope);
    final resumedToken =
        existing?.cartId == cartId ? existing?.accessToken : null;
    await sessionStore.write(
      StorefrontCartSession(
        scope: scope,
        cartId: cartId,
        accessToken: accessToken ?? resumedToken,
        revision: revision,
        expiresAt: expiresAt,
      ),
    );
  }

  /// Persists a newer response revision from ETag or a typed body fallback.
  Future<void> persistRevision({
    required String locationId,
    required String cartId,
    required String? etag,
    required int? fallback,
  }) async {
    final candidate = parseCartRevision(etag) ?? fallback;
    if (candidate == null) {
      return;
    }
    final scope = scopeFor(locationId);
    final existing = await sessionStore.read(scope);
    if (existing == null) {
      await capture(
        locationId: locationId,
        cartId: cartId,
        revision: candidate,
      );
      return;
    }
    if (existing.cartId != cartId || candidate <= existing.revision) {
      return;
    }
    await sessionStore.write(existing.withRevision(candidate));
  }

  /// Removes the guest capability after a successful customer claim.
  Future<void> removeCapability({
    required String locationId,
    required String cartId,
  }) async {
    final scope = scopeFor(locationId);
    final existing = await sessionStore.read(scope);
    if (existing?.cartId == cartId && existing?.accessToken != null) {
      await sessionStore.write(existing!.withoutAccessToken());
    }
  }

  /// Clears a session only when it belongs to [cartId].
  Future<void> clear({
    required String locationId,
    required String cartId,
  }) async {
    final scope = scopeFor(locationId);
    final existing = await sessionStore.read(scope);
    if (existing?.cartId == cartId) {
      await sessionStore.delete(scope);
    }
  }
}

/// Shares identical in-flight ordering-session starts.
final class OrderingSessionCoordinator {
  final Map<String, Future<Object?>> _pending = {};

  /// Runs [operation] once while the same [key] is in flight.
  Future<T> run<T>(String key, Future<T> Function() operation) {
    final existing = _pending[key];
    if (existing != null) {
      return existing as Future<T>;
    }

    late Future<T> request;
    request = operation().whenComplete(() {
      if (identical(_pending[key], request)) {
        _pending.remove(key);
      }
    });
    _pending[key] = request;
    return request;
  }
}
