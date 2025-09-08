import 'dart:convert';
import 'dart:math';

/// Very lightweight multipart/form-data builder producing bytes and headers.
class Multipart {
  final String boundary;
  final List<_Part> _parts = [];

  Multipart._(this.boundary);

  factory Multipart.random() {
    final rand = Random();
    final b = List.generate(24, (_) => rand.nextInt(36))
        .map((n) => n.toRadixString(36))
        .join();
    return Multipart._('----https-$b');
    // (changed prefix from prohttp to https)
  }

  void addField(String name, String value, {String? contentType}) {
    _parts.add(_Part.field(name, value, contentType: contentType));
  }

  void addFile(String name, String filename, List<int> bytes,
      {String? contentType}) {
    _parts.add(_Part.file(name, filename, bytes, contentType: contentType));
  }

  List<int> finalize() {
    final crlf = '\r\n';
    final List<int> out = [];
    for (final p in _parts) {
      out.addAll(utf8.encode('--$boundary$crlf'));
      out.addAll(utf8.encode(p.headers));
      out.addAll(utf8.encode(crlf));
      out.addAll(p.bytes);
      out.addAll(utf8.encode(crlf));
    }
    out.addAll(utf8.encode('--$boundary--$crlf'));
    return out;
  }

  String get contentType => 'multipart/form-data; boundary=$boundary';
}

class _Part {
  final String headers;
  final List<int> bytes;

  _Part.field(String name, String value, {String? contentType})
      : headers = [
    'Content-Disposition: form-data; name="$name"',
    if (contentType != null) 'Content-Type: $contentType',
  ].join('\r\n'),
        bytes = utf8.encode(value);

  _Part.file(String name, String filename, List<int> fileBytes,
      {String? contentType})
      : headers = [
    'Content-Disposition: form-data; name="$name"; filename="$filename"',
    'Content-Transfer-Encoding: binary',
    if (contentType != null) 'Content-Type: $contentType',
  ].join('\r\n'),
        bytes = fileBytes;
}
