import 'dart:async';
import 'response.dart';

typedef ShouldRetryError = bool Function(Object error, StackTrace st);
typedef ShouldRetryResponse = bool Function(Response resp);

class RetryPolicy {
  final int maxAttempts; // includes first try
  final Duration baseDelay;
  final Duration? maxDelay;
  final ShouldRetryError? retryOnError;
  final ShouldRetryResponse? retryOnResponse;

  const RetryPolicy({
    this.maxAttempts = 1,
    this.baseDelay = const Duration(milliseconds: 200),
    this.maxDelay,
    this.retryOnError,
    this.retryOnResponse,
  });
}

Future<T> runWithRetry<T>(
    Future<T> Function() body,
    RetryPolicy policy,
    ) async {
  var attempt = 0;
  var delay = policy.baseDelay;

  while (true) {
    attempt += 1;
    try {
      return await body();
    } catch (e, st) {
      final can = attempt < policy.maxAttempts &&
          (policy.retryOnError?.call(e, st) ?? false);
      if (!can) rethrow;
      await Future.delayed(delay);
      final next = delay * 2;
      delay = (policy.maxDelay != null && next > policy.maxDelay!)
          ? policy.maxDelay!
          : next;
    }
  }
}
