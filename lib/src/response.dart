import 'dart:typed_data';

class Response<T> {
  final T? data;
  final int statusCode;
  final Map<String, String> headers;
  final Uri requestUrl;
  final String method;
  final Duration? totalDuration;

  Response({
    required this.statusCode,
    required this.headers,
    required this.requestUrl,
    required this.method,
    this.data,
    this.totalDuration,
  });

  bool get ok => statusCode >= 200 && statusCode < 300;

  @override
  String toString() =>
      'Response($statusCode ${method.toUpperCase()} $requestUrl, ok=$ok)';
}

class StreamedResponse {
  final Stream<List<int>> stream;
  final int statusCode;
  final Map<String, String> headers;
  final Uri requestUrl;
  final String method;

  StreamedResponse({
    required this.stream,
    required this.statusCode,
    required this.headers,
    required this.requestUrl,
    required this.method,
  });
}

typedef Bytes = Uint8List;
