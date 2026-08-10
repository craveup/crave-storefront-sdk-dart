import 'session.dart';

/// Application-owned persistence for guest-cart recovery state.
abstract interface class StorefrontSessionStore {
  /// Reads the session isolated by [scope].
  Future<StorefrontCartSession?> read(StorefrontSessionScope scope);

  /// Persists [session]. Implementations must not regress a cart revision.
  Future<void> write(StorefrontCartSession session);

  /// Removes the session isolated by [scope].
  Future<void> delete(StorefrontSessionScope scope);
}

/// Ephemeral session storage for tests and demos.
///
/// Flutter production applications should provide an encrypted storage
/// adapter instead.
final class InMemoryStorefrontSessionStore implements StorefrontSessionStore {
  /// Creates empty ephemeral session storage.
  InMemoryStorefrontSessionStore();

  final Map<StorefrontSessionScope, StorefrontCartSession> _sessions = {};

  @override
  Future<StorefrontCartSession?> read(StorefrontSessionScope scope) async =>
      _sessions[scope];

  @override
  Future<void> write(StorefrontCartSession session) async {
    final existing = _sessions[session.scope];
    if (existing != null &&
        existing.cartId == session.cartId &&
        existing.revision > session.revision) {
      return;
    }
    final next = existing != null &&
            existing.cartId == session.cartId &&
            existing.accessToken == null &&
            session.accessToken != null
        ? session.withoutAccessToken()
        : session;
    _sessions[session.scope] = next;
  }

  @override
  Future<void> delete(StorefrontSessionScope scope) async {
    _sessions.remove(scope);
  }
}
