import 'package:crave_storefront_sdk/src/session/session.dart';
import 'package:crave_storefront_sdk/src/session/session_store.dart';
import 'package:test/test.dart';

void main() {
  group('Storefront cart sessions', () {
    test('isolate the same identifiers across origin, merchant, and location',
        () async {
      final store = InMemoryStorefrontSessionStore();
      final scopes = [
        StorefrontSessionScope(
          apiOrigin: Uri.parse('https://staging-api.example.test'),
          merchantSlug: 'merchant-a',
          locationId: 'location-a',
        ),
        StorefrontSessionScope(
          apiOrigin: Uri.parse('https://api.example.test'),
          merchantSlug: 'merchant-a',
          locationId: 'location-a',
        ),
        StorefrontSessionScope(
          apiOrigin: Uri.parse('https://api.example.test'),
          merchantSlug: 'merchant-b',
          locationId: 'location-a',
        ),
        StorefrontSessionScope(
          apiOrigin: Uri.parse('https://api.example.test'),
          merchantSlug: 'merchant-a',
          locationId: 'location-b',
        ),
      ];

      for (var index = 0; index < scopes.length; index += 1) {
        await store.write(
          StorefrontCartSession(
            scope: scopes[index],
            cartId: 'cart-$index',
            accessToken: 'capability-$index',
            revision: index,
          ),
        );
      }

      for (var index = 0; index < scopes.length; index += 1) {
        expect((await store.read(scopes[index]))?.cartId, 'cart-$index');
      }
    });

    test('updates monotonically and can remove only the guest capability',
        () async {
      final store = InMemoryStorefrontSessionStore();
      final scope = StorefrontSessionScope(
        apiOrigin: Uri.parse('https://api.example.test'),
        merchantSlug: 'merchant-a',
        locationId: 'location-a',
      );
      final original = StorefrontCartSession(
        scope: scope,
        cartId: 'cart-1',
        accessToken: 'guest-capability',
        revision: 4,
      );

      await store.write(original);
      await store.write(original.withRevision(3));
      expect((await store.read(scope))?.revision, 4);

      await store.write(original.withRevision(5).withoutAccessToken());
      final claimed = await store.read(scope);
      expect(claimed?.cartId, 'cart-1');
      expect(claimed?.revision, 5);
      expect(claimed?.accessToken, isNull);

      await store.delete(scope);
      expect(await store.read(scope), isNull);
    });
  });

  test('session values never stringify capabilities', () {
    final session = StorefrontCartSession(
      scope: StorefrontSessionScope(
        apiOrigin: Uri.parse('https://api.example.test'),
        merchantSlug: 'merchant-a',
        locationId: 'location-a',
      ),
      cartId: 'cart-1',
      accessToken: 'never-print-this-capability',
      revision: 1,
    );

    expect(session.toString(), isNot(contains('never-print-this-capability')));
  });
}
