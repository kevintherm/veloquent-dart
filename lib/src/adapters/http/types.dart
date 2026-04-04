class HttpRequest {
  const HttpRequest({
    required this.url,
    required this.method,
    this.headers,
    this.body,
    this.timeout,
  });

  final String url;
  final String method;
  final Map<String, String>? headers;
  final dynamic body;
  final Duration? timeout;
}

class HttpResponse {
  const HttpResponse({
    required this.status,
    required this.statusText,
    required this.headers,
    required this.data,
  });

  final int status;
  final String statusText;
  final Map<String, String> headers;
  final dynamic data;
}

abstract class HttpAdapter {
  Future<HttpResponse> request(HttpRequest request);
}
