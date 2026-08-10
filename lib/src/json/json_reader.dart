/// Reads an untrusted JSON object with contextual, value-safe type errors.
final class JsonReader {
  JsonReader._(this._values, this.context);

  /// Creates a reader for [value] at the supplied diagnostic [context].
  factory JsonReader.fromObject(
    Object? value, {
    required String context,
  }) {
    if (value is! Map<Object?, Object?>) {
      throw FormatException('Invalid JSON at $context: expected an object.');
    }

    final values = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw FormatException(
          'Invalid JSON at $context: expected string object keys.',
        );
      }
      values[key] = entry.value;
    }
    return JsonReader._(Map<String, Object?>.unmodifiable(values), context);
  }

  final Map<String, Object?> _values;

  /// The non-sensitive path used in decoding errors.
  final String context;

  /// Whether the object contains [key], including when its value is null.
  bool contains(String key) => _values.containsKey(key);

  /// Returns a shallow immutable view of this object for a nested decoder.
  Map<String, Object?> asMap() => _values;

  /// Returns a required string field.
  String string(String key) {
    final value = _values[key];
    if (value is String) return value;
    throw _typeError(key, 'a string');
  }

  /// Returns an optional or nullable string field.
  String? nullableString(String key) {
    final value = _values[key];
    if (value == null) return null;
    if (value is String) return value;
    throw _typeError(key, 'a string or null');
  }

  /// Returns a required, ISO-8601 timestamp while preserving its wire string.
  String timestamp(String key) {
    final value = string(key);
    if (DateTime.tryParse(value) == null) {
      throw _typeError(key, 'an ISO-8601 timestamp string');
    }
    return value;
  }

  /// Returns an optional ISO-8601 timestamp while preserving its wire string.
  String? nullableTimestamp(String key) {
    final value = nullableString(key);
    if (value == null) return null;
    if (DateTime.tryParse(value) == null) {
      throw _typeError(key, 'an ISO-8601 timestamp string or null');
    }
    return value;
  }

  /// Returns a required integer field.
  int integer(String key) {
    final value = _values[key];
    if (value is int) return value;
    throw _typeError(key, 'an integer');
  }

  /// Returns an optional or nullable integer field.
  int? nullableInteger(String key) {
    final value = _values[key];
    if (value == null) return null;
    if (value is int) return value;
    throw _typeError(key, 'an integer or null');
  }

  /// Returns a required finite numeric field as a double.
  double number(String key) {
    final value = _values[key];
    if (value is num && value.isFinite) return value.toDouble();
    throw _typeError(key, 'a finite number');
  }

  /// Returns an optional or nullable finite numeric field as a double.
  double? nullableNumber(String key) {
    final value = _values[key];
    if (value == null) return null;
    if (value is num && value.isFinite) return value.toDouble();
    throw _typeError(key, 'a finite number or null');
  }

  /// Returns a required boolean field.
  bool boolean(String key) {
    final value = _values[key];
    if (value is bool) return value;
    throw _typeError(key, 'a boolean');
  }

  /// Returns an optional or nullable boolean field.
  bool? nullableBoolean(String key) {
    final value = _values[key];
    if (value == null) return null;
    if (value is bool) return value;
    throw _typeError(key, 'a boolean or null');
  }

  /// Returns a reader for a required nested object field.
  JsonReader object(String key) => JsonReader.fromObject(
        _values[key],
        context: '$context.$key',
      );

  /// Returns a reader for an optional or nullable nested object field.
  JsonReader? nullableObject(String key) {
    if (_values[key] == null) return null;
    return object(key);
  }

  /// Returns readers for every object in a required list field.
  List<JsonReader> objectList(String key) {
    final value = _values[key];
    if (value is! List<Object?>) throw _typeError(key, 'a list');
    return List<JsonReader>.unmodifiable(
      value.indexed.map(
        (entry) => JsonReader.fromObject(
          entry.$2,
          context: '$context.$key[${entry.$1}]',
        ),
      ),
    );
  }

  /// Returns readers for an optional or nullable list, defaulting to empty.
  List<JsonReader> optionalObjectList(String key) {
    if (_values[key] == null) return const <JsonReader>[];
    return objectList(key);
  }

  /// Returns a required list of strings.
  List<String> stringList(String key) {
    final value = _values[key];
    if (value is! List<Object?>) throw _typeError(key, 'a list');
    final values = <String>[];
    for (final entry in value.indexed) {
      final item = entry.$2;
      if (item is! String) {
        throw FormatException(
          'Invalid JSON at $context.$key[${entry.$1}]: expected a string.',
        );
      }
      values.add(item);
    }
    return List<String>.unmodifiable(values);
  }

  /// Returns an optional or nullable list of strings, defaulting to empty.
  List<String> optionalStringList(String key) {
    if (_values[key] == null) return const <String>[];
    return stringList(key);
  }

  /// Returns a shallow immutable copy of an optional JSON object field.
  Map<String, Object?>? nullableMap(String key) {
    final value = _values[key];
    if (value == null) return null;
    return freezeJsonMap(object(key)._values, context: '$context.$key');
  }

  FormatException _typeError(String key, String expected) => FormatException(
        'Invalid JSON at $context.$key: expected $expected.',
      );
}

/// Copies a JSON object into deeply immutable maps and lists.
Map<String, Object?> freezeJsonMap(
  Map<String, Object?> value, {
  required String context,
}) {
  final frozen = _freezeJsonValue(value, context);
  return frozen! as Map<String, Object?>;
}

Object? _freezeJsonValue(Object? value, String context) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double) {
    if (value.isFinite) return value;
    throw FormatException(
      'Invalid JSON at $context: expected a finite number.',
    );
  }
  if (value is Map<Object?, Object?>) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw FormatException(
          'Invalid JSON at $context: expected string object keys.',
        );
      }
      result[key] = _freezeJsonValue(entry.value, '$context.$key');
    }
    return Map<String, Object?>.unmodifiable(result);
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(
      value.indexed.map(
        (entry) => _freezeJsonValue(
          entry.$2,
          '$context[${entry.$1}]',
        ),
      ),
    );
  }
  throw FormatException(
    'Invalid JSON at $context: expected a JSON-compatible value.',
  );
}
