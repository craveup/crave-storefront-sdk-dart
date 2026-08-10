import '../errors.dart';
import '../http/transport.dart';
import '../models/common.dart';
import '../models/customer.dart';
import '../runtime/request_runtime.dart';
import 'resource_support.dart';

const _maximumPageSize = 50;
const _maximumCursorLength = 512;

/// Customer identity, order, address, and saved-payment operations.
final class CustomersClient {
  /// Creates a customer resource client for one configured merchant.
  const CustomersClient(
    this._transport,
    this._merchantSlug,
    this._idempotencyKeyGenerator,
  );

  final StorefrontTransport _transport;
  final String _merchantSlug;
  final StorefrontIdempotencyKeyGenerator _idempotencyKeyGenerator;

  /// Starts customer authentication with a one-time passcode challenge.
  Future<LoginChallenge> requestLogin(
    CustomerLoginRequest request, {
    StorefrontRequestOptions? options,
  }) async {
    _requireConfiguredMerchant(request.merchantSlug);
    return _send<LoginChallenge>(
      method: 'POST',
      pathSegments: const ['customer', 'auth', 'login'],
      routeTemplate: '/customer/auth/login',
      authorization: StorefrontAuthorization.anonymous,
      body: request.toJson(),
      decoder: (value) => LoginChallenge.fromJson(decodeJsonObject(value)),
      options: options,
    );
  }

  /// Verifies a one-time passcode and returns a caller-owned customer JWT.
  Future<AuthResult> verifyOtp(
    VerifyOtpRequest request, {
    StorefrontRequestOptions? options,
  }) async {
    _requireConfiguredMerchant(request.merchantSlug);
    return _send<AuthResult>(
      method: 'POST',
      pathSegments: const ['customer', 'auth', 'verify-otp'],
      routeTemplate: '/customer/auth/verify-otp',
      authorization: StorefrontAuthorization.anonymous,
      body: request.toJson(),
      decoder: (value) => AuthResult.fromJson(decodeJsonObject(value)),
      options: options,
    );
  }

  /// Gets the authenticated customer's allowlisted profile.
  Future<StorefrontCustomer> getProfile({
    StorefrontRequestOptions? options,
  }) =>
      _send<StorefrontCustomer>(
        method: 'GET',
        pathSegments: const ['customer'],
        routeTemplate: '/customer',
        decoder: (value) =>
            StorefrontCustomer.fromJson(decodeJsonObject(value)),
        options: options,
      );

  /// Lists the authenticated customer's orders in cursor order.
  Future<CursorPage<PublicOrderSummary>> listOrders({
    int? limit,
    String? cursor,
    StorefrontRequestOptions? options,
  }) async {
    return _send<CursorPage<PublicOrderSummary>>(
      method: 'GET',
      pathSegments: const ['customer', 'orders'],
      routeTemplate: '/customer/orders',
      query: _paginationQuery(limit: limit, cursor: cursor),
      decoder: (value) => CursorPage<PublicOrderSummary>.fromJson(
        decodeJsonObject(value),
        PublicOrderSummary.fromJson,
      ),
      options: options,
    );
  }

  /// Gets an allowlisted order owned by the authenticated customer.
  Future<PublicOrderDetail> getOrder(
    String orderId, {
    StorefrontRequestOptions? options,
  }) =>
      _send<PublicOrderDetail>(
        method: 'GET',
        pathSegments: ['customer', 'orders', orderId],
        routeTemplate: '/customer/orders/:orderId',
        decoder: (value) => PublicOrderDetail.fromJson(decodeJsonObject(value)),
        options: options,
      );

  /// Lists the authenticated customer's saved delivery addresses.
  Future<CursorPage<CustomerAddress>> listAddresses({
    int? limit,
    String? cursor,
    StorefrontRequestOptions? options,
  }) async {
    return _send<CursorPage<CustomerAddress>>(
      method: 'GET',
      pathSegments: const ['customer', 'addresses'],
      routeTemplate: '/customer/addresses',
      query: _paginationQuery(limit: limit, cursor: cursor),
      decoder: (value) => CursorPage<CustomerAddress>.fromJson(
        decodeJsonObject(value),
        CustomerAddress.fromJson,
      ),
      options: options,
    );
  }

  /// Creates a saved delivery address as an idempotent mutation.
  Future<CustomerAddress> createAddress(
    CreateCustomerAddressRequest request, {
    StorefrontRequestOptions? options,
  }) =>
      _send<CustomerAddress>(
        method: 'POST',
        pathSegments: const ['customer', 'addresses'],
        routeTemplate: '/customer/addresses',
        body: request.toJson(),
        idempotent: true,
        decoder: (value) => CustomerAddress.fromJson(decodeJsonObject(value)),
        options: options,
      );

  /// Updates a saved address using the exact revision in [options].
  ///
  /// Supply the address's current revision through
  /// [StorefrontRequestOptions.revision]. Conflicts are surfaced without an
  /// implicit retry.
  Future<CustomerAddress> updateAddress(
    String addressId,
    UpdateCustomerAddressRequest request, {
    StorefrontRequestOptions? options,
  }) async {
    final revision = options?.revision;
    if (revision == null) {
      throw const StorefrontConfigurationException(
        'An address revision is required for address updates.',
      );
    }
    return _send<CustomerAddress>(
      method: 'PATCH',
      pathSegments: ['customer', 'addresses', addressId],
      routeTemplate: '/customer/addresses/:addressId',
      body: request.toJson(),
      idempotent: true,
      revision: StorefrontRevision.address(revision),
      decoder: (value) => CustomerAddress.fromJson(decodeJsonObject(value)),
      options: options,
    );
  }

  /// Deletes a saved address as an idempotent mutation.
  Future<DeleteCustomerAddressResult> deleteAddress(
    String addressId, {
    StorefrontRequestOptions? options,
  }) =>
      _send<DeleteCustomerAddressResult>(
        method: 'DELETE',
        pathSegments: ['customer', 'addresses', addressId],
        routeTemplate: '/customer/addresses/:addressId',
        idempotent: true,
        decoder: (value) =>
            DeleteCustomerAddressResult.fromJson(decodeJsonObject(value)),
        options: options,
      );

  /// Lists safe saved-payment references for the authenticated customer.
  Future<List<SavedPaymentMethod>> listSavedPayments({
    StorefrontRequestOptions? options,
  }) =>
      _send<List<SavedPaymentMethod>>(
        method: 'GET',
        pathSegments: const ['customer', 'saved-payments'],
        routeTemplate: '/customer/saved-payments',
        decoder: (value) => decodeJsonObjectList(value)
            .map(SavedPaymentMethod.fromJson)
            .toList(growable: false),
        options: options,
      );

  /// Removes a saved-payment reference owned by the authenticated customer.
  Future<SuccessResult> deleteSavedPayment(
    String paymentId, {
    StorefrontRequestOptions? options,
  }) =>
      _send<SuccessResult>(
        method: 'DELETE',
        pathSegments: ['customer', 'saved-payments', paymentId],
        routeTemplate: '/customer/saved-payments/:paymentId',
        decoder: (value) => SuccessResult.fromJson(decodeJsonObject(value)),
        options: options,
      );

  /// Revokes the current customer session.
  ///
  /// Applications remain responsible for clearing their own JWT source after
  /// this call succeeds.
  Future<SuccessResult> logout({StorefrontRequestOptions? options}) =>
      _send<SuccessResult>(
        method: 'DELETE',
        pathSegments: const ['customer', 'logout'],
        routeTemplate: '/customer/logout',
        decoder: (value) => SuccessResult.fromJson(decodeJsonObject(value)),
        options: options,
      );

  Future<T> _send<T>({
    required String method,
    required List<String> pathSegments,
    required String routeTemplate,
    required T Function(Object? value) decoder,
    StorefrontAuthorization authorization = StorefrontAuthorization.customer,
    Map<String, Object?> query = const {},
    Object? body,
    bool idempotent = false,
    StorefrontRevision? revision,
    StorefrontRequestOptions? options,
  }) async {
    final request = ResourceRequestOptions(options);
    final response = await _transport.send<T>(
      method: method,
      pathSegments: pathSegments,
      routeTemplate: routeTemplate,
      authorization: authorization,
      query: query,
      body: body,
      idempotencyKey: idempotent
          ? request.idempotencyKey ?? _idempotencyKeyGenerator.next()
          : null,
      revision: revision,
      decoder: decoder,
      timeout: request.timeout,
      cancellationToken: request.cancellationToken,
    );
    return response.data;
  }

  void _requireConfiguredMerchant(String merchantSlug) {
    if (merchantSlug != _merchantSlug) {
      throw const StorefrontConfigurationException(
        'The authentication merchantSlug must match the configured client.',
      );
    }
  }
}

Map<String, Object?> _paginationQuery({int? limit, String? cursor}) {
  if (limit != null && (limit < 1 || limit > _maximumPageSize)) {
    throw const StorefrontConfigurationException(
      'Pagination limit must be between 1 and 50.',
    );
  }
  if (cursor != null &&
      (cursor.isEmpty || cursor.length > _maximumCursorLength)) {
    throw const StorefrontConfigurationException(
      'Pagination cursor must contain between 1 and 512 characters.',
    );
  }
  return <String, Object?>{
    if (limit != null) 'limit': limit,
    if (cursor != null) 'cursor': cursor,
  };
}
