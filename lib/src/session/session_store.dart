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
    _sessions[session.scope] = session;
  }

  @override
  Future<void> delete(StorefrontSessionScope scope) async {
    _sessions.remove(scope);
  }
}
