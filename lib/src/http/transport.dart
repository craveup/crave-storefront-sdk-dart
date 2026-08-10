import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../auth.dart';
import '../cancellation.dart';
import '../errors.dart';
import '../origin.dart';

const _apiPath = <String>['api', 'v1', 'storefront'];
const _defaultTimeout = Duration(seconds: 10);
const _defaultMaxResponseBytes = 16 * 1024 * 1024;
final _idempotencyKeyPattern = RegExp(r'^[A-Za-z0-9._:-]{16,128}$');
final _credentialHeaderPattern = RegExp(r'^[\x21-\x7e]+$');
final _errorCodePattern = RegExp(r'^[A-Z][A-Z0-9_]{0,63}$');
final _requestIdPattern = RegExp(r'^[A-Za-z0-9._:-]{1,128}$');
final _fieldPathPattern = RegExp(r'^[A-Za-z0-9_.\[\]-]{1,128}$');

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
  /// Creates a decoded response with safe selected metadata.
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
    this.maxResponseBytes = _defaultMaxResponseBytes,
  })  : baseUri = normalizeStorefrontOrigin(baseUri),
        _client = client ?? http.Client(),
        _ownsClient = client == null {
    if (defaultTimeout <= Duration.zero) {
      throw const StorefrontConfigurationException(
        'The default timeout must be greater than zero.',
      );
    }
    if (maxResponseBytes <= 0) {
      throw const StorefrontConfigurationException(
        'The maximum response size must be greater than zero.',
      );
    }
  }

  /// Canonical origin used by the transport.
  final Uri baseUri;

  /// Optional caller-owned provider for customer authentication.
  final StorefrontCustomerTokenProvider? customerTokenProvider;

  /// Default request deadline.
  final Duration defaultTimeout;

  /// Maximum response body retained before safe decoding stops.
  final int maxResponseBytes;

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
    if (pathSegments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw const StorefrontConfigurationException(
        'Storefront path segments must be non-empty resource identifiers.',
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
    _AbortCause? abortCause;
    void abortWith(_AbortCause cause) {
      if (!abort.isCompleted) {
        abortCause = cause;
        abort.complete();
      }
    }

    if (cancellationToken?.isCancelled ?? false) {
      abortWith(_AbortCause.cancelled);
    }
    unawaited(cancellationToken?.whenCancelled.then((_) {
      abortWith(_AbortCause.cancelled);
    }));
    final timer = Timer(deadline, () {
      abortWith(_AbortCause.timeout);
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
      late http.Response response;
      try {
        response = await _readBoundedResponse(streamedResponse);
      } on _ResponseTooLarge {
        if (streamedResponse.statusCode < 200 ||
            streamedResponse.statusCode >= 300) {
          throw StorefrontApiException(
            statusCode: streamedResponse.statusCode,
            code: 'HTTP_ERROR',
            message: _safeApiMessage(streamedResponse.statusCode),
            requestId: _sanitizeRequestId(
              streamedResponse.headers['x-request-id'],
            ),
            retryIdempotencyKey: _ambiguousReplayKey(
              streamedResponse.statusCode,
              idempotencyKey,
            ),
            method: method,
            routeTemplate: routeTemplate,
          );
        }
        throw StorefrontDecodingException(
          method: method,
          routeTemplate: routeTemplate,
          retryIdempotencyKey: idempotencyKey,
        );
      }
      final success = response.statusCode >= 200 && response.statusCode < 300;
      final headerRequestId = _sanitizeRequestId(
        response.headers['x-request-id'],
      );
      Object? parsed;
      try {
        parsed = _parseJson(response.body, response.statusCode);
      } on FormatException {
        if (success) {
          rethrow;
        }
      }
      if (!success) {
        final envelope = parsed is Map
            ? parsed.cast<String, Object?>()
            : const <String, Object?>{};
        throw StorefrontApiException(
          statusCode: response.statusCode,
          code: _sanitizeErrorCode(envelope['code']) ?? 'HTTP_ERROR',
          message: _safeApiMessage(response.statusCode),
          requestId:
              _sanitizeRequestId(envelope['requestId']) ?? headerRequestId,
          details: _sanitizeDetails(envelope['details']),
          retryIdempotencyKey: _ambiguousReplayKey(
            response.statusCode,
            idempotencyKey,
          ),
          method: method,
          routeTemplate: routeTemplate,
        );
      }
      try {
        return StorefrontTransportResponse<T>(
          data: decoder(parsed),
          etag: response.headers['etag'],
          requestId: headerRequestId,
        );
      } on StorefrontException {
        rethrow;
      } catch (_) {
        throw StorefrontDecodingException(
          method: method,
          routeTemplate: routeTemplate,
          retryIdempotencyKey: idempotencyKey,
        );
      }
    } on _Aborted {
      if (abortCause == _AbortCause.timeout) {
        throw StorefrontTimeoutException(
          method: method,
          routeTemplate: routeTemplate,
          timeout: deadline,
          retryIdempotencyKey: idempotencyKey,
        );
      }
      throw StorefrontRequestCancelledException(
        method: method,
        routeTemplate: routeTemplate,
        retryIdempotencyKey: idempotencyKey,
      );
    } on http.RequestAbortedException {
      if (abortCause == _AbortCause.timeout) {
        throw StorefrontTimeoutException(
          method: method,
          routeTemplate: routeTemplate,
          timeout: deadline,
          retryIdempotencyKey: idempotencyKey,
        );
      }
      throw StorefrontRequestCancelledException(
        method: method,
        routeTemplate: routeTemplate,
        retryIdempotencyKey: idempotencyKey,
      );
    } on StorefrontException {
      rethrow;
    } on FormatException {
      throw StorefrontDecodingException(
        method: method,
        routeTemplate: routeTemplate,
        retryIdempotencyKey: idempotencyKey,
      );
    } on http.ClientException {
      throw StorefrontNetworkException(
        method: method,
        routeTemplate: routeTemplate,
        retryIdempotencyKey: idempotencyKey,
      );
    } catch (_) {
      throw StorefrontNetworkException(
        method: method,
        routeTemplate: routeTemplate,
        retryIdempotencyKey: idempotencyKey,
      );
    } finally {
      timer.cancel();
    }
  }

  Future<http.Response> _readBoundedResponse(
    http.StreamedResponse response,
  ) async {
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in response.stream) {
      length += chunk.length;
      if (length > maxResponseBytes) {
        throw const _ResponseTooLarge();
      }
      bytes.add(chunk);
    }
    return http.Response.bytes(
      bytes.takeBytes(),
      response.statusCode,
      headers: response.headers,
      request: response.request,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  Future<void> _applyAuthorization(
    http.Request request, {
    required StorefrontAuthorization authorization,
    required String? cartToken,
    required String? checkoutHandoffToken,
    required String? receiptToken,
  }) async {
    String? optionalCredential(String? value, String description) {
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      if (value.length > 8192 || !_credentialHeaderPattern.hasMatch(value)) {
        throw StorefrontConfigurationException(
          '$description has an invalid header format.',
        );
      }
      return value;
    }

    Future<String?> customerToken() async {
      final token = await customerTokenProvider?.call();
      return optionalCredential(token, 'The customer token');
    }

    void requireHeader(String name, String? value, String description) {
      final credential = optionalCredential(value, description);
      if (credential == null) {
        throw StorefrontConfigurationException('$description is required.');
      }
      request.headers[name] = credential;
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
        final capability = optionalCredential(cartToken, 'The cart capability');
        if (capability != null) {
          request.headers['x-cart-token'] = capability;
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
        final capability =
            optionalCredential(receiptToken, 'The receipt capability');
        if (capability != null) {
          request.headers['x-receipt-token'] = capability;
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

Object? _parseJson(String body, int statusCode) {
  if (statusCode == 204 || body.trim().isEmpty) {
    return null;
  }
  return jsonDecode(body);
}

String _safeApiMessage(int statusCode) =>
    'The Storefront API rejected the request with status $statusCode.';

String? _ambiguousReplayKey(int statusCode, String? idempotencyKey) =>
    idempotencyKey != null && (statusCode == 408 || statusCode >= 500)
        ? idempotencyKey
        : null;

String? _sanitizeErrorCode(Object? value) =>
    value is String && _errorCodePattern.hasMatch(value) ? value : null;

String? _sanitizeRequestId(Object? value) =>
    value is String && _requestIdPattern.hasMatch(value) ? value : null;

Map<String, Object?>? _sanitizeDetails(Object? value) {
  if (value is! Map) {
    return null;
  }
  final rawFields = value['fields'];
  if (rawFields is! List) {
    return null;
  }
  final fields = <Map<String, Object?>>[];
  for (final rawField in rawFields) {
    if (rawField is Map) {
      final path = rawField['path'];
      if (path is String && _fieldPathPattern.hasMatch(path)) {
        fields.add({'path': path});
      }
    }
  }
  return {'fields': fields};
}

final class _Aborted implements Exception {
  const _Aborted();
}

enum _AbortCause { timeout, cancelled }

final class _ResponseTooLarge implements Exception {
  const _ResponseTooLarge();
}
