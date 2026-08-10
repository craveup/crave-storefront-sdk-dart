import 'dart:async';

import '../session/session.dart';
import '../session/session_store.dart';
import 'request_runtime.dart';

/// Session-derived inputs for one cart request.
final class CartRequestContext {
  /// Creates request context selected by the shared cart runtime.
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
  CartSessionRuntime({
    required this.apiOrigin,
    required this.merchantSlug,
    required this.sessionStore,
    required this.idempotencyKeyGenerator,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Canonical API origin.
  final Uri apiOrigin;

  /// Canonical merchant slug.
  final String merchantSlug;

  /// Caller-owned storage adapter.
  final StorefrontSessionStore sessionStore;

  /// Cryptographically secure idempotency-key generator.
  final StorefrontIdempotencyKeyGenerator idempotencyKeyGenerator;

  final DateTime Function() _now;
  final Map<StorefrontSessionScope, Future<void>> _scopeUpdates = {};
  final Map<(StorefrontSessionScope, String), Future<void>> _cartOperations =
      {};

  /// Returns the isolated storage scope for [locationId].
  StorefrontSessionScope scopeFor(String locationId) => StorefrontSessionScope(
        apiOrigin: apiOrigin,
        merchantSlug: merchantSlug,
        locationId: locationId,
      );

  /// Serializes the complete request lifecycle for one scoped cart.
  ///
  /// HTTP requests for different carts remain independent. Ordering the same
  /// cart prevents an older response from persisting state after a later
  /// delete or capability transition has completed.
  Future<T> serializeCartOperation<T>({
    required String locationId,
    required String cartId,
    required Future<void> Function(Future<void> previous) waitForPrevious,
    required Future<T> Function() operation,
  }) =>
      _serialize(
        _cartOperations,
        (scopeFor(locationId), cartId),
        operation,
        waitForPrevious: waitForPrevious,
      );

  /// Returns a matching non-expired session for [locationId], when available.
  Future<StorefrontCartSession?> activeSessionFor(String locationId) async {
    final scope = scopeFor(locationId);
    final stored = await _matchingSession(scope);
    return stored == null || stored.isExpiredAt(_now()) ? null : stored;
  }

  /// Selects capability, revision, and idempotency data for a cart call.
  Future<CartRequestContext> contextFor({
    required String locationId,
    required String cartId,
    required bool idempotent,
    required bool revisionRequired,
    StorefrontRequestOptions? options,
    bool allowExpiredSession = false,
  }) async {
    final scope = scopeFor(locationId);
    final stored = allowExpiredSession
        ? await _matchingSession(scope)
        : await activeSessionFor(locationId);
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
    await _withScopeUpdate(scope, () async {
      await _captureUnlocked(
        scope: scope,
        cartId: cartId,
        revision: revision,
        accessToken: accessToken,
        expiresAt: expiresAt,
      );
    });
  }

  Future<void> _captureUnlocked({
    required StorefrontSessionScope scope,
    required String cartId,
    required int revision,
    String? accessToken,
    DateTime? expiresAt,
  }) async {
    final existing = await _matchingSession(scope);
    final resumedToken =
        existing?.cartId == cartId ? existing?.accessToken : null;
    final resumedExpiry =
        existing?.cartId == cartId ? existing?.expiresAt : null;
    await sessionStore.write(
      StorefrontCartSession(
        scope: scope,
        cartId: cartId,
        accessToken: accessToken ?? resumedToken,
        revision: revision,
        expiresAt: expiresAt ?? resumedExpiry,
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
    await _withScopeUpdate(scope, () async {
      final existing = await _matchingSession(scope);
      if (existing == null) {
        await _captureUnlocked(
          scope: scope,
          cartId: cartId,
          revision: candidate,
        );
        return;
      }
      if (existing.cartId != cartId || candidate <= existing.revision) {
        return;
      }
      await sessionStore.write(existing.withRevision(candidate));
    });
  }

  /// Removes the guest capability after a successful customer claim.
  Future<void> removeCapability({
    required String locationId,
    required String cartId,
  }) async {
    final scope = scopeFor(locationId);
    await _withScopeUpdate(scope, () async {
      final existing = await _matchingSession(scope);
      if (existing?.cartId == cartId && existing?.accessToken != null) {
        await sessionStore.write(existing!.withoutAccessToken());
      }
    });
  }

  /// Clears a session only when it belongs to [cartId].
  Future<void> clear({
    required String locationId,
    required String cartId,
  }) async {
    final scope = scopeFor(locationId);
    await _withScopeUpdate(scope, () async {
      final existing = await _matchingSession(scope);
      if (existing?.cartId == cartId) {
        await sessionStore.delete(scope);
      }
    });
  }

  Future<StorefrontCartSession?> _matchingSession(
    StorefrontSessionScope scope,
  ) async {
    final stored = await sessionStore.read(scope);
    return stored?.scope == scope ? stored : null;
  }

  Future<T> _withScopeUpdate<T>(
    StorefrontSessionScope scope,
    Future<T> Function() operation,
  ) =>
      _serialize(_scopeUpdates, scope, operation);
}

Future<T> _serialize<K, T>(
  Map<K, Future<void>> queue,
  K key,
  Future<T> Function() operation, {
  Future<void> Function(Future<void> previous)? waitForPrevious,
}) async {
  final previous = queue[key];
  final gate = Completer<void>();
  final next = gate.future;
  queue[key] = next;
  void release() {
    if (!gate.isCompleted) {
      gate.complete();
    }
    if (identical(queue[key], next)) {
      final _ = queue.remove(key);
    }
  }

  if (previous != null) {
    try {
      await (waitForPrevious?.call(previous) ?? previous);
    } on Object {
      unawaited(previous.then((_) => release()));
      rethrow;
    }
  }
  try {
    return await operation();
  } finally {
    release();
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
