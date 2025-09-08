import 'dart:convert';

Map<String, String> normalizeHeaders(Map<String, String> headers) {
  final out = <String, String>{};
  for (final e in headers.entries) {
    out[e.key.trim()] = e.value;
  }
  return out;
}

Uri mergeQuery(Uri base, Map<String, String> extra) {
  final merged = {...base.queryParameters, ...extra};
  return base.replace(queryParameters: merged.isEmpty ? null : merged);
}

Object? jsonDecodeSafe(String s) {
  if (s.isEmpty) return null;
  try {
    return jsonDecode(s);
  } catch (_) {
    return s; // not JSON
  }
}
