class CookieJar {
  // host -> cookieName -> value
  final Map<String, Map<String, String>> _store = {};

  void save(String host, Map<String, String> cookies) {
    final m = _store.putIfAbsent(host, () => {});
    m.addAll(cookies);
  }

  String? headerFor(String host) {
    final m = _store[host];
    if (m == null || m.isEmpty) return null;
    return m.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  void saveFromSetCookieHeaders(String host, Iterable<String> setCookieHeaders) {
    final m = _store.putIfAbsent(host, () => {});
    for (final line in setCookieHeaders) {
      final first = line.split(';').first;
      final idx = first.indexOf('=');
      if (idx > 0) {
        final name = first.substring(0, idx).trim();
        final value = first.substring(idx + 1).trim();
        m[name] = value;
      }
    }
  }

  void clearHost(String host) => _store.remove(host);
  void clearAll() => _store.clear();
}
