import 'package:crave_storefront_sdk/src/json/json_reader.dart';
import 'package:test/test.dart';

void main() {
  group('JsonReader', () {
    test('reads typed values without dynamic calls', () {
      final reader = JsonReader.fromObject(
        <String, Object?>{
          'name': 'Example Tea',
          'count': 2,
          'enabled': true,
          'metadata': <String, Object?>{'source': 'fixture'},
        },
        context: 'merchant',
      );

      expect(reader.string('name'), 'Example Tea');
      expect(reader.integer('count'), 2);
      expect(reader.boolean('enabled'), isTrue);
      expect(reader.object('metadata').string('source'), 'fixture');
      expect(reader.nullableString('description'), isNull);
    });

    test('reports context but never the rejected value', () {
      const sensitive = 'otp-123456-top-secret';
      final reader = JsonReader.fromObject(
        <String, Object?>{'customerName': sensitive},
        context: 'customer',
      );

      expect(
        () => reader.integer('customerName'),
        throwsA(
          isA<FormatException>()
              .having(
                (error) => error.message,
                'message',
                contains('customer.customerName'),
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains(sensitive)),
              ),
        ),
      );
    });

    test('adds an index to malformed list item context', () {
      final reader = JsonReader.fromObject(
        <String, Object?>{
          'items': <Object?>[
            <String, Object?>{'id': 'item_01'},
            'private-value',
          ],
        },
        context: 'cart',
      );

      expect(
        () => reader.objectList('items'),
        throwsA(
          isA<FormatException>()
              .having(
                (error) => error.message,
                'message',
                contains(r'cart.items[1]'),
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('private-value')),
              ),
        ),
      );
    });

    test('deeply freezes decoded JSON maps', () {
      final nested = <String, Object?>{'value': 'original'};
      final reader = JsonReader.fromObject(
        <String, Object?>{
          'metadata': <String, Object?>{'nested': nested},
        },
        context: 'cart',
      );
      final metadata = reader.nullableMap('metadata')!;

      nested['value'] = 'changed';

      expect(
        (metadata['nested']! as Map<String, Object?>)['value'],
        'original',
      );
      expect(
        () => (metadata['nested']! as Map<String, Object?>)['value'] = 'x',
        throwsUnsupportedError,
      );
    });
  });
}
