import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constructs the SDK from a Flutter consumer', () {
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.com'),
      merchantSlug: 'example-merchant',
    );

    expect(client.baseUri, Uri.parse('https://api.example.com'));
    expect(client.merchantSlug, 'example-merchant');
    client.close();
  });
}
