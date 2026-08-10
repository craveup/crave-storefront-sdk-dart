import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';

void main() {
  final client = CraveStorefrontClient(
    baseUri: Uri.parse('https://api.example.com'),
    merchantSlug: 'example-merchant',
  );

  client.close();
}
