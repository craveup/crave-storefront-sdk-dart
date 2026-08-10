import 'dart:async';

/// A cooperative cancellation signal for an in-flight Storefront request.
final class StorefrontCancellationToken {
  final Completer<void> _completer = Completer<void>();

  /// Completes when [cancel] is called.
  Future<void> get whenCancelled => _completer.future;

  /// Whether cancellation has already been requested.
  bool get isCancelled => _completer.isCompleted;

  /// Requests cancellation. Calling this more than once has no effect.
  void cancel() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}
