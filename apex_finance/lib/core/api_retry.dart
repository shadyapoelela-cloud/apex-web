import 'package:http/http.dart' as http;

/// Cold-start retry helper for Render free tier.
/// Retries up to 3 times with increasing timeouts (10s → 20s)
/// and treats 502/503/504 as retriable gateway errors.
class ApiRetry {
  static Future<http.Response> _attempt(
    Future<http.Response> Function() call,
    String method,
    String url,
  ) async {
    Object? lastErr;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final timeout = Duration(seconds: attempt == 1 ? 10 : 20);
        final r = await call().timeout(timeout);
        if (attempt < 3 && (r.statusCode == 502 || r.statusCode == 503 || r.statusCode == 504)) {
          await Future.delayed(Duration(seconds: attempt * 3));
          continue;
        }
        return r;
      } catch (e) {
        lastErr = e;
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 3));
        }
      }
    }
    throw Exception('ApiRetry $method $url failed after 3 attempts: $lastErr');
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    _attempt(() => http.get(url, headers: headers), 'GET', url.toString());

  static Future<http.Response> post(Uri url,
    {Map<String, String>? headers, Object? body}) =>
    _attempt(() => http.post(url, headers: headers, body: body), 'POST', url.toString());

  static Future<http.Response> put(Uri url,
    {Map<String, String>? headers, Object? body}) =>
    _attempt(() => http.put(url, headers: headers, body: body), 'PUT', url.toString());
}
