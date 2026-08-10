import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth.dart';
import '../cancellation.dart';
import '../errors.dart';

const _apiPath = <String>['api', 'v1', 'storefront'];
const _defaultTimeout = Duration(seconds: 10);
final _idempotencyKeyPattern = RegExp(r'^[A-Za-z0-9._:-]{16,128}$');

/// Determines which narrowly scoped credential a request may use.
enum StorefrontAuthorization {
  /// No credential is acquired or attached.
  anonymous,

  /// A customer JWT is attached when the caller has one.
  optionalCustomer,

  /// A customer JWT is required.
  customer,

  /// A cart capability is preferred, otherwise a customer JWT is required.
  cart,

  /// A guest cart capability is required and a JWT is never attached.
  cartCapability,

  /// Both a guest cart capability and customer JWT are required.
  cartAndCustomer,

  /// A call-scoped checkout-handoff capability is required.
  checkoutHandoff,

  /// A receipt capability is preferred, otherwise a customer JWT is required.
  receiptOrCustomer,
}

/// A conditional revision header managed by the Storefront SDK.
final class StorefrontRevision {
  const StorefrontRevision._(this.resource, this.value);

  /// Creates a cart revision precondition.
  const StorefrontRevision.cart(int value) : this._('cart', value);

  /// Creates an address revision precondition.
  const StorefrontRevision.address(int value) : this._('address', value);

  /// Resource name used in the ETag contract.
  final String resource;

  /// Non-negative monotonically increasing revision.
  final int value;

  String get _headerValue => '"$resource-$value"';
}

/// Decoded transport result and selected safe response metadata.
final class StorefrontTransportResponse<T> {
  const StorefrontTransportResponse({
    required this.data,
    this.etag,
    this.requestId,
  });

  /// Decoded response value.
  final T data;

  /// Resource ETag returned by the API, when available.
  final String? etag;

  /// Correlation ID returned by the API, when available.
  final String? requestId;
}

/// Internal same-origin JSON transport for reviewed Storefront operations.
final class StorefrontTransport {
  /// Creates a transport.
  ///
  /// [baseUri] must be an origin-only HTTPS URI outside loopback development.
  StorefrontTransport({
    required Uri baseUri,
    http.Client? client,
    this.customerTokenProvider,
    this.defaultTimeout = _defaultTimeout,
  })  : baseUri = _normalizeBaseUri(baseUri),
        _client = client ?? http.Client(),
        _ownsClient = client == null {
    if (defaultTimeout <= Duration.zero) {
      throw const StorefrontConfigurationException(
        'The default timeout must be greater than zero.',
      );
    }
  }

  /// Canonical origin used by the transport.
  final Uri baseUri;

  /// Optional caller-owned provider for customer authentication.
  final StorefrontCustomerTokenProvider? customerTokenProvider;

  /// Default request deadline.
  final Duration defaultTimeout;

  final http.Client _client;
  final bool _ownsClient;
  bool _closed = false;

  /// Sends one reviewed Storefront operation.
  ///
  /// Resource clients supply fixed [pathSegments] and [routeTemplate] values;
  /// this method is internal and is not exported by the package entrypoint.
  Future<StorefrontTransportResponse<T>> send<T>({
    required String method,
    required List<String> pathSegments,
    required String routeTemplate,
    required T Function(Object? value) decoder,
    StorefrontAuthorization authorization = StorefrontAuthorization.anonymous,
    Map<String, Object?> query = const {},
    Object? body,
    String? cartToken,
    String? checkoutHandoffToken,
    String? receiptToken,
    String? idempotencyKey,
    StorefrontRevision? revision,
    Duration? timeout,
    StorefrontCancellationToken? cancellationToken,
  }) async {
    if (_closed) {
      throw const StorefrontConfigurationException(
        'The Storefront client has already been closed.',
      );
    }
    final deadline = timeout ?? defaultTimeout;
    if (deadline <= Duration.zero) {
      throw const StorefrontConfigurationException(
        'The request timeout must be greater than zero.',
      );
    }
    if (pathSegments.any((segment) => segment.isEmpty)) {
      throw const StorefrontConfigurationException(
        'Storefront path segments must not be empty.',
      );
    }
    if (idempotencyKey != null &&
        !_idempotencyKeyPattern.hasMatch(idempotencyKey)) {
      throw const StorefrontConfigurationException(
        'Idempotency keys must contain 16 to 128 safe characters.',
      );
    }
    if (revision != null && revision.value < 0) {
      throw const StorefrontConfigurationException(
        'A resource revision must not be negative.',
      );
    }

    final queryParameters = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null) {
        queryParameters[entry.key] = value.toString();
      }
    }
    final url = baseUri.replace(
      pathSegments: [..._apiPath, ...pathSegments],
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final abort = Completer<void>();
    var timedOut = false;
    var cancelled = cancellationToken?.isCancelled ?? false;
    if (cancelled) {
      abort.complete();
    }
    unawaited(cancellationToken?.whenCancelled.then((_) {
      cancelled = true;
      if (!abort.isCompleted) {
        abort.complete();
      }
    }));
    final timer = Timer(deadline, () {
      timedOut = true;
      if (!abort.isCompleted) {
        abort.complete();
      }
    });

    final request = http.AbortableRequest(
      method,
      url,
      abortTrigger: abort.future,
    )
      ..followRedirects = false
      ..headers['accept'] = 'application/json';
    if (body != null) {
      request
        ..headers['content-type'] = 'application/json; charset=utf-8'
        ..body = jsonEncode(body);
    }
    if (idempotencyKey != null) {
      request.headers['idempotency-key'] = idempotencyKey;
    }
    if (revision != null) {
      request.headers['if-match'] = revision._headerValue;
    }
    try {
      await Future.any<void>([
        _applyAuthorization(
          request,
          authorization: authorization,
          cartToken: cartToken,
          checkoutHandoffToken: checkoutHandoffToken,
          receiptToken: receiptToken,
        ),
        abort.future.then<void>((_) => throw const _Aborted()),
      ]);
      final streamedResponse = await Future.any<http.StreamedResponse>([
        _client.send(request),
        abort.future.then<http.StreamedResponse>((_) => throw const _Aborted()),
      ]);
      final response = await http.Response.fromStream(streamedResponse);
      final requestId = response.headers['x-request-id'];
      final parsed = _parseJson(response.body, response.statusCode);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final envelope = parsed is Map
            ? parsed.cast<String, Object?>()
            : const <String, Object?>{};
        final code = envelope['code'];
        throw StorefrontApiException(
          statusCode: response.statusCode,
          code: code is String ? code : 'HTTP_ERROR',
          message: _safeApiMessage(response.statusCode),
          requestId: envelope['requestId'] is String
              ? envelope['requestId']! as String
              : requestId,
          details: _sanitizeDetails(envelope['details']),
          method: method,
          routeTemplate: routeTemplate,
        );
      }
      try {
        return StorefrontTransportResponse<T>(
          data: decoder(parsed),
          etag: response.headers['etag'],
          requestId: requestId,
        );
      } on StorefrontException {
        rethrow;
      } catch (_) {
        throw StorefrontDecodingException(
          method: method,
          routeTemplate: routeTemplate,
        );
      }
    } on _Aborted {
      if (timedOut && !cancelled) {
        throw StorefrontTimeoutException(
          method: method,
          routeTemplate: routeTemplate,
          timeout: deadline,
        );
      }
      throw StorefrontRequestCancelledException(
        method: method,
        routeTemplate: routeTemplate,
      );
    } on http.RequestAbortedException {
      if (timedOut && !cancelled) {
        throw StorefrontTimeoutException(
          method: method,
          routeTemplate: routeTemplate,
          timeout: deadline,
        );
      }
      throw StorefrontRequestCancelledException(
        method: method,
        routeTemplate: routeTemplate,
      );
    } on StorefrontException {
      rethrow;
    } on FormatException {
      throw StorefrontDecodingException(
        method: method,
        routeTemplate: routeTemplate,
      );
    } on http.ClientException {
      throw StorefrontNetworkException(
        method: method,
        routeTemplate: routeTemplate,
      );
    } catch (_) {
      throw StorefrontNetworkException(
        method: method,
        routeTemplate: routeTemplate,
      );
    } finally {
      timer.cancel();
    }
  }

  Future<void> _applyAuthorization(
    http.Request request, {
    required StorefrontAuthorization authorization,
    required String? cartToken,
    required String? checkoutHandoffToken,
    required String? receiptToken,
  }) async {
    Future<String?> customerToken() async {
      final token = await customerTokenProvider?.call();
      return token == null || token.trim().isEmpty ? null : token;
    }

    void requireHeader(String name, String? value, String description) {
      if (value == null || value.trim().isEmpty) {
        throw StorefrontConfigurationException('$description is required.');
      }
      request.headers[name] = value;
    }

    Future<void> requireCustomer() async {
      final token = await customerToken();
      if (token == null) {
        throw const StorefrontConfigurationException(
          'A customer token is required for this operation.',
        );
      }
      request.headers['authorization'] = 'Bearer $token';
    }

    switch (authorization) {
      case StorefrontAuthorization.anonymous:
        return;
      case StorefrontAuthorization.optionalCustomer:
        final token = await customerToken();
        if (token != null) {
          request.headers['authorization'] = 'Bearer $token';
        }
      case StorefrontAuthorization.customer:
        await requireCustomer();
      case StorefrontAuthorization.cart:
        if (cartToken != null && cartToken.trim().isNotEmpty) {
          request.headers['x-cart-token'] = cartToken;
        } else {
          await requireCustomer();
        }
      case StorefrontAuthorization.cartCapability:
        requireHeader('x-cart-token', cartToken, 'A cart capability');
      case StorefrontAuthorization.cartAndCustomer:
        requireHeader('x-cart-token', cartToken, 'A cart capability');
        await requireCustomer();
      case StorefrontAuthorization.checkoutHandoff:
        requireHeader(
          'x-checkout-handoff',
          checkoutHandoffToken,
          'A checkout handoff capability',
        );
      case StorefrontAuthorization.receiptOrCustomer:
        if (receiptToken != null && receiptToken.trim().isNotEmpty) {
          request.headers['x-receipt-token'] = receiptToken;
        } else {
          await requireCustomer();
        }
    }
  }

  /// Closes an internally created HTTP client.
  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    if (_ownsClient) {
      _client.close();
    }
  }
}

Uri _normalizeBaseUri(Uri uri) {
  final isLoopback =
      uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
  final validScheme =
      uri.scheme == 'https' || (isLoopback && uri.scheme == 'http');
  final originOnly = uri.hasScheme &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment;
  if (!validScheme || !originOnly) {
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

Object? _parseJson(String body, int statusCode) {
  if (statusCode == 204 || body.trim().isEmpty) {
    return null;
  }
  return jsonDecode(body);
}

String _safeApiMessage(int statusCode) =>
    'The Storefront API rejected the request with status $statusCode.';

Map<String, Object?>? _sanitizeDetails(Object? value) {
  if (value is! Map) {
    return null;
  }
  final details = value.cast<String, Object?>();
  final rawFields = details['fields'];
  if (rawFields is! List) {
    return null;
  }
  final fields = <Map<String, Object?>>[];
  for (final rawField in rawFields) {
    if (rawField is Map) {
      final field = rawField.cast<String, Object?>();
      final path = field['path'];
      if (path is String && path.length <= 128) {
        fields.add({'path': path});
      }
    }
  }
  return {'fields': fields};
}

final class _Aborted implements Exception {
  const _Aborted();
}
