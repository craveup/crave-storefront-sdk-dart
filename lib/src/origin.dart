import 'errors.dart';

/// Whether [uri] is HTTPS, or loopback HTTP for local development.
bool isSecureStorefrontWebUri(Uri uri) {
  final isLoopback =
      uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
  return uri.isAbsolute &&
      uri.host.isNotEmpty &&
      (uri.scheme == 'https' || (isLoopback && uri.scheme == 'http'));
}

/// Validates and canonicalizes a Storefront API origin.
Uri normalizeStorefrontOrigin(Uri uri) {
  final originOnly = uri.hasScheme &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment;
  if (!isSecureStorefrontWebUri(uri) || !originOnly) {
    throw const StorefrontConfigurationException(
      'baseUri must be an origin-only HTTPS URI, except for loopback development.',
    );
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );
}
