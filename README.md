# pro_http

Dio-like, feature-rich HTTP client for Dart/Flutter.

### Highlights
- Interceptors (request / response / error)
- Retries with exponential backoff & conditions
- Cancellation tokens
- Progress (upload & download)
- Multipart form uploads
- Cookie jar (in-memory) + Set-Cookie handling
- Download to file
- JSON helpers
- Adapters: default (package:http). Swap or mock easily.

```dart
import 'package:pro_http/pro_http.dart';

void main() async {
  final httpx = ProHttp(
    baseUrl: Uri.parse('https://jsonplaceholder.typicode.com'),
    interceptors: [LogInterceptor()],
    retryPolicy: RetryPolicy(
      maxAttempts: 3,
      retryOnResponse: (r) => r.statusCode >= 500,
      retryOnError: (e, _) => true,
    ),
  );

  final resp = await httpx.get('/todos/1');
  print(resp.data);
}
