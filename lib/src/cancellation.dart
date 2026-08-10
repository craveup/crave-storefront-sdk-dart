import 'dart:async';

/// A cooperative cancellation signal for one logical Storefront operation.
final class StorefrontCancellationToken {
  /// Creates a cancellation signal to discard after the operation settles.
  StorefrontCancellationToken();

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
