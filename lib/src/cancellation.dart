class CancelToken {
  bool _cancelled = false;
  Object? _reason;

  bool get isCancelled => _cancelled;
  Object? get reason => _reason;

  void cancel([Object? reason]) {
    _cancelled = true;
    _reason = reason ?? 'Cancelled';
  }

  void throwIfCancelled() {
    if (_cancelled) {
      throw CancelledError(_reason ?? 'Cancelled');
    }
  }
}

class CancelledError implements Exception {
  final Object reason;
  CancelledError(this.reason);
  @override
  String toString() => 'CancelledError($reason)';
}
