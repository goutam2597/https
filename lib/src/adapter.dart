import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'cancellation.dart';
import 'request.dart';
import 'response.dart';

/// Adapter sends RequestOptions and returns a StreamedResponse or full Response.
/// DefaultAdapter uses package:http under the hood.
abstract class HttpAdapter {
  Future<StreamedResponse> sendStreamed(
      RequestOptions options, {
        CancelToken? cancelToken,
        void Function(int sent, int? total)? onSendProgress,
      });

  Future<Response<List<int>>> sendBytes(
      RequestOptions options, {
        CancelToken? cancelToken,
        void Function(int received, int? total)? onReceiveProgress,
      });

  void close();
}

class DefaultAdapter implements HttpAdapter {
  http.Client _client = http.Client();

  @override
  Future<StreamedResponse> sendStreamed(
      RequestOptions options, {
        CancelToken? cancelToken,
        void Function(int sent, int? total)? onSendProgress,
      }) async {
    cancelToken?.throwIfCancelled();

    final req = http.StreamedRequest(options.method, _withQuery(options));

    // headers
    options.headers.forEach((k, v) => req.headers[k] = v);

    // body (support String, bytes, Map, Stream)
    if (options.body != null) {
      if (options.body is String) {
        final bytes = (options.encoding ?? utf8).encode(options.body as String);
        req.contentLength = bytes.length;
        onSendProgress?.call(bytes.length, bytes.length);
        req.sink.add(bytes);
        await req.sink.close();
      } else if (options.body is List<int>) {
        final bytes = options.body as List<int>;
        req.contentLength = bytes.length;
        onSendProgress?.call(bytes.length, bytes.length);
        req.sink.add(bytes);
        await req.sink.close();
      } else if (options.body is Map) {
        final fields = (options.body as Map).cast<String, String>();
        final encoded = Uri(queryParameters: fields).query;
        final bytes = (options.encoding ?? utf8).encode(encoded);
        req.headers.putIfAbsent(
          'Content-Type',
              () => 'application/x-www-form-urlencoded',
        );
        req.contentLength = bytes.length;
        onSendProgress?.call(bytes.length, bytes.length);
        req.sink.add(bytes);
        await req.sink.close();
      } else if (options.body is Stream<List<int>>) {
        await req.sink.addStream(options.body as Stream<List<int>>);
        await req.sink.close();
      } else {
        throw ArgumentError('Unsupported body type: ${options.body.runtimeType}');
      }
    } else {
      await req.sink.close();
    }

    // Timeout the request future itself
    final future = _client.send(req);
    final http.StreamedResponse raw = options.timeout == null
        ? await future
        : await future.timeout(options.timeout!);

    cancelToken?.throwIfCancelled();

    return StreamedResponse(
      stream: raw.stream,
      statusCode: raw.statusCode,
      headers: Map<String, String>.from(raw.headers),
      requestUrl: _withQuery(options),
      method: options.method,
    );
  }

  @override
  Future<Response<List<int>>> sendBytes(
      RequestOptions options, {
        CancelToken? cancelToken,
        void Function(int received, int? total)? onReceiveProgress,
      }) async {
    final streamed = await sendStreamed(
      options,
      cancelToken: cancelToken,
    );

    // Enforce a timeout on the response stream too
    final timeout = options.timeout ?? const Duration(seconds: 25);
    final chunks = <int>[];
    int received = 0;
    final total = int.tryParse(streamed.headers['content-length'] ?? '');

    await for (final c in streamed.stream.timeout(timeout)) {
      chunks.addAll(c);
      received += c.length;
      onReceiveProgress?.call(received, total);
      cancelToken?.throwIfCancelled();
    }

    return Response<List<int>>(
      statusCode: streamed.statusCode,
      headers: streamed.headers,
      requestUrl: streamed.requestUrl,
      method: streamed.method,
      data: chunks,
    );
  }

  Uri _withQuery(RequestOptions o) => o.query.isEmpty
      ? o.url
      : o.url.replace(queryParameters: {
    ...o.url.queryParameters,
    ...o.query,
  });

  @override
  void close() {
    _client.close();
    _client = http.Client();
  }
}
