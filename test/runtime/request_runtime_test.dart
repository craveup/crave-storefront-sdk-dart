import 'package:crave_storefront_sdk/src/runtime/request_runtime.dart';
import 'package:test/test.dart';

void main() {
  test('parses strong and weak cart ETags', () {
    expect(parseCartRevision('"cart-12"'), 12);
    expect(parseCartRevision('W/"cart-13"'), 13);
    expect(parseCartRevision('address-13'), isNull);
    expect(parseCartRevision('W/"cart-secret"'), isNull);
    expect(parseCartRevision(null), isNull);
  });

  test('parses only address-scoped revision ETags', () {
    expect(parseAddressRevision('"address-4"'), 4);
    expect(parseAddressRevision('W/"address-5"'), 5);
    expect(parseAddressRevision('"cart-4"'), isNull);
    expect(parseAddressRevision('address-4'), isNull);
    expect(parseAddressRevision(null), isNull);
  });

  test('generates safe unique idempotency keys', () {
    final generator = StorefrontIdempotencyKeyGenerator();
    final keys = List.generate(100, (_) => generator.next());

    expect(keys.toSet(), hasLength(keys.length));
    for (final key in keys) {
      expect(key, matches(RegExp(r'^[A-Za-z0-9._:-]{16,128}$')));
    }
  });
}
