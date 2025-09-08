import 'dart:async';
import 'request.dart';
import 'response.dart';

abstract class Interceptor {
  FutureOr<RequestOptions> onRequest(RequestOptions options) => options;

  FutureOr<Response<dynamic>> onResponse(Response resp) => resp;

  FutureOr onError(Object error, StackTrace st) => Future.error(error, st);
}

class LogInterceptor extends Interceptor {
  final void Function(String) log;
  LogInterceptor({void Function(String)? logger}) : log = logger ?? print;

  @override
  FutureOr<RequestOptions> onRequest(RequestOptions options) {
    log('→ ${options.method.toUpperCase()} ${options.url}');
    if (options.headers.isNotEmpty) {
      for (final e in options.headers.entries) {
        log('  ${e.key}: ${e.value}');
      }
    }
    return options;
  }

  @override
  FutureOr<Response> onResponse(Response resp) {
    log('← ${resp.statusCode} ${resp.method.toUpperCase()} ${resp.requestUrl}');
    return resp;
  }

  @override
  FutureOr onError(Object error, StackTrace st) {
    log('! ERROR: $error');
    return Future.error(error, st);
  }
}
