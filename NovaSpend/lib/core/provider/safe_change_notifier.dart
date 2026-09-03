import 'package:flutter/foundation.dart';

/// [ChangeNotifier] that ignores [notifyListeners] after [dispose].
///
/// Async work started with `unawaited` can finish after the widget tree has
/// already dropped the provider (sign-out, expired session). Flutter asserts
/// if [notifyListeners] runs in that state.
class SafeChangeNotifier extends ChangeNotifier {
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
