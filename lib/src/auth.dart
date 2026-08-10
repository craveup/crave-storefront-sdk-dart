/// Async callback that returns the current customer JWT, if signed in.
typedef StorefrontCustomerTokenProvider = Future<String?> Function();
