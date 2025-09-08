import 'dart:convert';
import 'dart:io';

import 'adapter.dart';
import 'cancellation.dart';
import 'cookie_jar.dart';
import 'interceptor.dart';
import 'request.dart';
import 'response.dart';
import 'retry.dart';
import 'utils.dart';

class Https {
  final Uri? baseUrl;
  final Map<String, String> defaultHeaders;
  final Map<String, String> defaultQuery;
  final Duration? requestTimeout;
  final List<Interceptor> interceptors;
  final RetryPolicy retryPolicy;
  final CookieJar cookieJar;
  final HttpAdapter _adapter;

  Https({
    this.baseUrl,
    Map<String, String>? defaultHeaders,
    Map<String, String>? defaultQuery,
    this.requestTimeout,
    List<Interceptor>? interceptors,
    RetryPolicy? retryPolicy,
    CookieJar? cookieJar,
    HttpAdapter? adapter,
  })  : defaultHeaders = {...?defaultHeaders},
        defaultQuery = {...?defaultQuery},
        interceptors = [...?interceptors],
        retryPolicy = retryPolicy ?? const RetryPolicy(),
        cookieJar = cookieJar ?? CookieJar(),
        _adapter = adapter ?? DefaultAdapter();

  // -----------------------
  // Public high-level API
  // -----------------------
  Future<Response<dynamic>> get(
      Object url, {
        Map<String, String>? headers,
        Map<String, String>? query,
        CancelToken? cancelToken,
        void Function(int received, int? total)? onReceiveProgress,
      }) =>
      _request(
        'GET',
        url,
        headers: headers,
        query: query,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );

  Future<Response<dynamic>> delete(
      Object url, {
        Map<String, String>? headers,
        Map<String, String>? query,
        Object? data,
        CancelToken? cancelToken,
        void Function(int received, int? total)? onReceiveProgress,
      }) =>
      _request(
        'DELETE',
        url,
        headers: headers,
        query: query,
        data: data,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );

  Future<Response<dynamic>> head(
      Object url, {
        Map<String, String>? headers,
        Map<String, String>? query,
        CancelToken? cancelToken,
      }) =>
      _request(
        'HEAD',
        url,
        headers: headers,
        query: query,
        cancelToken: cancelToken,
      );

  Future<Response<dynamic>> post(
      Object url, {
        Map<String, String>? headers,
        Map<String, String>? query,
        Object? data,
        CancelToken? cancelToken,
        void Function(int sent, int? total)? onSendProgress,
        void Function(int received, int? total)? onReceiveProgress,
      }) =>
      _request(
        'POST',
        url,
        headers: headers,
        query: query,
        data: data,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

  Future<Response<dynamic>> put(
      Object url, {
        Map<String, String>? headers,
        Map<String, String>? query,
        Object? data,
        CancelToken? cancelToken,
        void Function(int sent, int? total)? onSendProgress,
        void Function(int received, int? total)? onReceiveProgress,
      }) =>
      _request(
        'PUT',
        url,
        headers: headers,
        query: query,
        data: data,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

  Future<Response<dynamic>> patch(
      Object url, {
        Map<String, String>? headers,
        Map<String, String>? query,
        Object? data,
        CancelToken? cancelToken,
        void Function(int sent, int? total)? onSendProgress,
        void Function(int received, int? total)? onReceiveProgress,
      }) =>
      _request(
        'PATCH',
        url,
        headers: headers,
        query: query,
        data: data,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

  /// JSON helpers
  Future<T?> getJson<T>(Object url,
      {Map<String, String>? headers,
        Map<String, String>? query,
        CancelToken? cancelToken}) async {
    final r = await get(url, headers: headers, query: query, cancelToken: cancelToken);
    return r.data as T?;
  }

  Future<T?> postJson<T>(Object url,
      {Object? data,
        Map<String, String>? headers,
        Map<String, String>? query,
        CancelToken? cancelToken}) async {
    final hdrs = {'Content-Type': 'application/json', ...?headers};
    final body = data == null ? null : jsonEncode(data);
    final r = await post(url,
        headers: hdrs, query: query, data: body, cancelToken: cancelToken);
    return r.data as T?;
  }

  /// Download to file path (mobile/desktop). Returns saved path.
  Future<String> download(
      Object url, {
        required String saveToPath,
        Map<String, String>? headers,
        Map<String, String>? query,
        CancelToken? cancelToken,
        void Function(int received, int? total)? onReceiveProgress,
      }) async {
    final options = _buildOptions('GET', url,
        headers: headers, query: query, data: null);
    final resp = await _sendBytesWithChain(
      options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
    final file = File(saveToPath);
    await file.writeAsBytes(resp.data ?? <int>[]);
    return saveToPath;
  }

  void close() => _adapter.close();

  // -----------------------
  // Core pipeline
  // -----------------------
  Future<Response<dynamic>> _request(
      String method,
      Object url, {
        Map<String, String>? headers,
        Map<String, String>? query,
        Object? data,
        CancelToken? cancelToken,
        void Function(int sent, int? total)? onSendProgress,
        void Function(int received, int? total)? onReceiveProgress,
      }) async {
    final options =
    _buildOptions(method, url, headers: headers, query: query, data: data);

    // Run through interceptors + retry
    final sw = Stopwatch()..start();
    try {
      final resp = await runWithRetry<Response<List<int>>>(() async {
        final reqAfter = await _applyRequestInterceptors(options);

        // Cookie header
        final cookieHeader = cookieJar.headerFor(reqAfter.url.host);
        final headersWithCookie = {
          ...reqAfter.headers,
          if (cookieHeader != null) 'Cookie': [
            if (reqAfter.headers['Cookie'] != null) reqAfter.headers['Cookie']!,
            cookieHeader
          ].where((e) => e != null && e.isNotEmpty).join('; ')
        };

        final finalReq = reqAfter.copyWith(headers: headersWithCookie);

        final raw = await _adapter.sendBytes(
          finalReq,
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
        );

        // Save Set-Cookie
        final setCookies = raw.headers.entries
            .where((e) => e.key.toLowerCase() == 'set-cookie')
            .map((e) => e.value);
        if (setCookies.isNotEmpty) {
          cookieJar.saveFromSetCookieHeaders(finalReq.url.host, setCookies);
        }

        final decoded = _decodeBody(finalReq, raw);
        final wrapped = Response<dynamic>(
          statusCode: raw.statusCode,
          headers: raw.headers,
          requestUrl: raw.requestUrl,
          method: raw.method,
          data: decoded,
        );

        // Response interceptors
        final r2 = await _applyResponseInterceptors(wrapped);

        // Decide if retry by response
        if (retryPolicy.retryOnResponse?.call(r2) ?? false) {
          throw _RetryByResponse();
        }
        return Response<List<int>>(
          statusCode: r2.statusCode,
          headers: r2.headers,
          requestUrl: r2.requestUrl,
          method: r2.method,
          data: _encodeAgainIfNeeded(r2.data),
        );
      }, retryPolicy);

      sw.stop();
      return Response<dynamic>(
        statusCode: resp.statusCode,
        headers: resp.headers,
        requestUrl: resp.requestUrl,
        method: resp.method,
        data: _decodeByContentType(resp.headers, resp.data),
        totalDuration: sw.elapsed,
      );
    } catch (e, st) {
      // Error interceptors
      await _applyErrorInterceptors(e, st);
      rethrow; // if not recovered
    }
  }

  RequestOptions _buildOptions(String method, Object url,
      {Map<String, String>? headers, Map<String, String>? query, Object? data}) {
    Uri uri = url is Uri ? url : Uri.parse(url.toString());
    if (baseUrl != null && !uri.hasScheme) {
      uri = baseUrl!.resolveUri(uri);
    }
    if ((query ?? {}).isNotEmpty) {
      uri = mergeQuery(uri, query!);
    }
    if (defaultQuery.isNotEmpty) {
      uri = mergeQuery(uri, defaultQuery);
    }

    return RequestOptions(
      method: method.toUpperCase(),
      url: uri,
      headers: normalizeHeaders({...defaultHeaders, ...?headers}),
      body: data,
      timeout: requestTimeout,
    );
  }

  Future<RequestOptions> _applyRequestInterceptors(RequestOptions options) async {
    var current = options;
    for (final i in interceptors) {
      final res = await i.onRequest(current);
      current = res;
    }
    return current;
  }

  Future<Response<dynamic>> _applyResponseInterceptors(Response resp) async {
    var current = resp;
    for (final i in interceptors.reversed) {
      final res = await i.onResponse(current);
      current = res;
    }
    return current;
  }

  Future<void> _applyErrorInterceptors(Object error, StackTrace st) async {
    Object err = error;
    StackTrace trace = st;
    for (final i in interceptors.reversed) {
      try {
        final res = await i.onError(err, trace);
        if (res is Response) {
          // recovered to a response: stop error propagation
          return;
        }
      } catch (e, s) {
        err = e;
        trace = s;
      }
    }
    // if not recovered, let caller rethrow
  }

  Response<dynamic> _decodeBody(
      RequestOptions req, Response<List<int>> rawBytes) {
    final decoded = _decodeByContentType(rawBytes.headers, rawBytes.data);
    return Response<dynamic>(
      statusCode: rawBytes.statusCode,
      headers: rawBytes.headers,
      requestUrl: rawBytes.requestUrl,
      method: rawBytes.method,
      data: decoded,
    );
  }

  dynamic _decodeByContentType(Map<String, String> headers, List<int>? bytes) {
    if (bytes == null) return null;
    final ct = headers.entries
        .firstWhere((e) => e.key.toLowerCase() == 'content-type',
        orElse: () => const MapEntry('', ''))
        .value
        .toLowerCase();
    final bodyStr = utf8.decode(bytes, allowMalformed: true);

    if (ct.contains('application/json') ||
        ct.contains('+json') ||
        bodyStr.trimLeft().startsWith('{') ||
        bodyStr.trimLeft().startsWith('[')) {
      return jsonDecodeSafe(bodyStr);
    }
    return bodyStr;
  }

  List<int>? _encodeAgainIfNeeded(dynamic data) {
    if (data == null) return null;
    if (data is List<int>) return data;
    if (data is String) return utf8.encode(data);
    return utf8.encode(jsonEncode(data));
  }

  Future<Response<List<int>>> _sendBytesWithChain(
      RequestOptions options, {
        CancelToken? cancelToken,
        void Function(int received, int? total)? onReceiveProgress,
      }) async {
    return _adapter.sendBytes(
      options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }
}

class _RetryByResponse implements Exception {}
