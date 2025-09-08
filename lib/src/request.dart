import 'dart:convert';

class RequestOptions {
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final Map<String, String> query;
  final Object? body;
  final Encoding? encoding;
  final Duration? timeout;
  final bool followRedirects;
  final int maxRedirects;

  const RequestOptions({
    required this.method,
    required this.url,
    this.headers = const {},
    this.query = const {},
    this.body,
    this.encoding,
    this.timeout,
    this.followRedirects = true,
    this.maxRedirects = 5,
  });

  RequestOptions copyWith({
    String? method,
    Uri? url,
    Map<String, String>? headers,
    Map<String, String>? query,
    Object? body = _sentinel,
    Encoding? encoding,
    Duration? timeout = _sentinelDur,
    bool? followRedirects,
    int? maxRedirects,
  }) {
    return RequestOptions(
      method: method ?? this.method,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      query: query ?? this.query,
      body: identical(body, _sentinel) ? this.body : body,
      encoding: encoding ?? this.encoding,
      timeout: identical(timeout, _sentinelDur) ? this.timeout : timeout,
      followRedirects: followRedirects ?? this.followRedirects,
      maxRedirects: maxRedirects ?? this.maxRedirects,
    );
  }
}

const _sentinel = Object();
const _sentinelDur = Duration(days: 987654);
