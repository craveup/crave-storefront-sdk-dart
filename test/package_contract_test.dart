import 'dart:io';

import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('package contract', () {
    test('exposes the expected package identity and a single entrypoint', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final publicLibraries = Directory('lib')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.uri.pathSegments.last)
          .toList();

      expect(pubspec, contains('name: crave_storefront_sdk'));
      expect(pubspec, contains('version: 0.2.0'));
      expect(
        pubspec,
        contains(
          'documentation: https://docs.craveup.com/getting-started/flutter-storefront-sdk',
        ),
      );
      expect(pubspec, contains('sdk: ">=3.4.0 <4.0.0"'));
      expect(pubspec, isNot(contains('sdk: flutter')));
      expect(pubspec, isNot(contains('path:')));
      expect(pubspec, isNot(contains('git:')));
      expect(publicLibraries, ['crave_storefront_sdk.dart']);
    });

    test('constructs a typed client without a private credential', () {
      Future<String?> tokenProvider() async => null;
      final client = CraveStorefrontClient(
        baseUri: Uri.parse('https://api.example.test'),
        merchantSlug: 'example-merchant',
        customerTokenProvider: tokenProvider,
      );

      expect(client.baseUri, Uri.parse('https://api.example.test'));
      expect(client.merchantSlug, 'example-merchant');
      client.close();
    });
  });
}
