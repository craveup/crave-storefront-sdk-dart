import '../cancellation.dart';
import '../runtime/request_runtime.dart';

/// Converts a decoded JSON value to an object map.
Map<String, Object?> decodeJsonObject(Object? value) =>
    (value as Map).cast<String, Object?>();

/// Converts a decoded JSON value to a list of object maps.
List<Map<String, Object?>> decodeJsonObjectList(Object? value) =>
    (value as List)
        .map((item) => (item as Map).cast<String, Object?>())
        .toList(growable: false);

/// Transport values projected from public request options.
final class ResourceRequestOptions {
  const ResourceRequestOptions(this.source);

  final StorefrontRequestOptions? source;

  Duration? get timeout => source?.timeout;
  StorefrontCancellationToken? get cancellationToken =>
      source?.cancellationToken;
  String? get idempotencyKey => source?.idempotencyKey;
  int? get revision => source?.revision;
}
