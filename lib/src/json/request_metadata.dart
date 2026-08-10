import 'dart:convert';

import 'json_reader.dart';

const _maximumRequestPayloadBytes = 8 * 1024;
const _sensitiveKeyFragments = <String>{
  'token',
  'authorization',
  'email',
  'phone',
  'address',
  'clientsecret',
  'password',
};
final _nonAlphanumeric = RegExp('[^a-z0-9]');

/// Rejects metadata keys the Storefront API classifies as sensitive.
void validateStorefrontMetadata(Map<String, Object?>? metadata) {
  if (_containsSensitiveMetadataKey(metadata)) {
    throw ArgumentError(
      'Metadata must not contain customer data or credential fields.',
    );
  }
}

/// Validates and deeply freezes caller metadata without echoing rejected data.
Map<String, Object?>? prepareStorefrontMetadata(
  Map<String, Object?>? metadata, {
  required String context,
}) {
  if (metadata == null) {
    return null;
  }
  try {
    validateStorefrontMetadata(metadata);
    return freezeJsonMap(metadata, context: context);
  } on Object {
    throw ArgumentError(
      'Metadata must be JSON-compatible and contain no sensitive fields.',
    );
  }
}

/// Rejects a Storefront request whose UTF-8 JSON payload exceeds 8 KiB.
void validateStorefrontPayloadSize(Map<String, Object?> payload) {
  if (utf8.encode(jsonEncode(payload)).length > _maximumRequestPayloadBytes) {
    throw ArgumentError('The request payload must not exceed 8 KiB.');
  }
}

bool _containsSensitiveMetadataKey(Object? value) {
  if (value is List<Object?>) {
    return value.any(_containsSensitiveMetadataKey);
  }
  if (value is! Map<Object?, Object?>) {
    return false;
  }
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is String) {
      final normalized = key.toLowerCase().replaceAll(_nonAlphanumeric, '');
      if (_sensitiveKeyFragments.any(normalized.contains)) {
        return true;
      }
    }
    if (_containsSensitiveMetadataKey(entry.value)) {
      return true;
    }
  }
  return false;
}
