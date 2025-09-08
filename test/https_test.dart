import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:https/https.dart';
import 'package:https/src/adapter.dart';


class FakeAdapter extends HttpAdapter {
  @override
  void close() {}

  @override
  Future<Response<List<int>>> sendBytes(RequestOptions options,
      {cancelToken, onReceiveProgress}) async {
    if (options.url.path.endsWith('/ok')) {
      final bytes = utf8.encode('{"ok":true}');
      return Response<List<int>>(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        requestUrl: options.url,
        method: options.method,
        data: bytes,
      );
    }
    return Response<List<int>>(
      statusCode: 404,
      headers: {'content-type': 'text/plain'},
      requestUrl: options.url,
      method: options.method,
      data: utf8.encode('nope'),
    );
  }

  @override
  Future<StreamedResponse> sendStreamed(RequestOptions options,
      {cancelToken, onSendProgress}) {
    throw UnimplementedError();
  }
}

void main() {
  test('basic json decode', () async {
    final client = Https(
      baseUrl: Uri.parse('https://example.com'),
      interceptors: [LogInterceptor()],
      adapter: FakeAdapter(),
    );

    final resp = await client.get('/ok');
    expect(resp.ok, true);
    expect(resp.data, isA<Map>());
    expect(resp.data['ok'], true);
  });

  test('not found text', () async {
    final client = Https(baseUrl: Uri.parse('https://example.com'), adapter: FakeAdapter());
    final resp = await client.get('/missing');
    expect(resp.ok, false);
    expect(resp.data, 'nope');
  });
}
