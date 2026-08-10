import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Map<String, Object?> manifest;
  late List<Map<String, Object?>> operations;

  setUpAll(() {
    manifest = jsonDecode(
      File('tool/storefront_operations.json').readAsStringSync(),
    ) as Map<String, Object?>;
    operations =
        (manifest['operations']! as List<Object?>).cast<Map<String, Object?>>();
  });

  group('storefront operation manifest', () {
    test('records the exact reviewed route inventory', () {
      expect(manifest['schemaVersion'], 1);
      expect(manifest['basePath'], '/api/v1/storefront');
      expect(
        manifest['source'],
        containsPair(
          'commit',
          '7fb18e9918f2181d426a73762cd97f3deb7d5418',
        ),
      );
      expect(operations, hasLength(50));

      final operationIds = operations
          .map((operation) => operation['operationId']! as String)
          .toSet();
      final methodPaths = operations
          .map(
            (operation) => '${operation['method']} ${operation['path']}',
          )
          .toSet();

      expect(operationIds, hasLength(50),
          reason: 'Operation IDs must be unique.');
      expect(
        methodPaths,
        hasLength(50),
        reason: 'Every HTTP method and path pair must be unique.',
      );
    });

    test('uses stable, bounded contract metadata', () {
      const methods = {'GET', 'POST', 'PATCH', 'PUT', 'DELETE'};
      const authModes = {
        'public',
        'optionalCustomer',
        'customer',
        'cart',
        'cartCapability',
        'cartAndCustomer',
        'checkoutHandoff',
        'receiptOrCustomer',
      };
      const revisionModes = {'none', 'cart', 'address'};

      for (final operation in operations) {
        final id = operation['operationId'];
        final path = operation['path'];

        expect(id, isA<String>());
        expect(id, matches(RegExp(r'^storefront[A-Z][A-Za-z0-9]+$')));
        expect(operation['method'], isIn(methods), reason: '$id method');
        expect(path, isA<String>());
        expect(
          path,
          startsWith('/api/v1/storefront/'),
          reason: '$id must remain inside the Storefront namespace.',
        );
        expect(operation['auth'], isIn(authModes), reason: '$id auth');
        expect(
          operation['idempotency'],
          isA<bool>(),
          reason: '$id idempotency flag',
        );
        expect(
          operation['revision'],
          isIn(revisionModes),
          reason: '$id revision',
        );
        expect(operation['etag'], isA<bool>(), reason: '$id ETag flag');
      }
    });

    test('exposes 49 typed JSON operations and excludes only the redirect', () {
      final typedJson = operations
          .where((operation) => operation['sdkMethod'] is String)
          .toList();
      final excluded = operations
          .where((operation) => operation['sdkMethod'] == null)
          .toList();
      final sdkMethods = typedJson
          .map((operation) => operation['sdkMethod']! as String)
          .toSet();

      expect(typedJson, hasLength(49));
      expect(
        sdkMethods,
        hasLength(49),
        reason: 'Every typed operation must have one unique public SDK method.',
      );
      expect(excluded, hasLength(1));
      expect(
        excluded.single,
        containsPair(
          'path',
          '/api/v1/storefront/locations/:locationId/redirect',
        ),
      );
      expect(excluded.single, containsPair('method', 'GET'));
      expect(excluded.single['exclusionReason'], isA<String>());
      expect(excluded.single['exclusionReason'], isNotEmpty);

      for (final operation in operations.where(
        (operation) => operation['sdkMethod'] != null,
      )) {
        expect(
          operation['sdkMethod'],
          matches(RegExp(r'^[a-z][A-Za-z0-9]+\.[a-z][A-Za-z0-9]+$')),
        );
        expect(operation.containsKey('exclusionReason'), isFalse);
      }
    });

    test('keeps concurrency metadata internally consistent', () {
      for (final operation in operations) {
        final id = operation['operationId'];
        final revision = operation['revision'];
        if (revision != 'none') {
          expect(
            operation['idempotency'],
            isTrue,
            reason: '$id uses optimistic concurrency and must be idempotent.',
          );
          expect(
            operation['etag'],
            isTrue,
            reason: '$id must return the next revision ETag.',
          );
        }
      }
    });
  });
}
