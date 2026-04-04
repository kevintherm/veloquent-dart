import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'types.dart';

class FetchAdapter implements HttpAdapter {
  FetchAdapter({
    this.timeout = const Duration(milliseconds: 30000),
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<HttpResponse> request(HttpRequest request) async {
    final headers = <String, String>{...?(request.headers)};

    Object? encodedBody;
    if (request.body != null) {
      if (request.body is String) {
        encodedBody = request.body as String;
      } else {
        encodedBody = jsonEncode(request.body);
      }
      headers.putIfAbsent('content-type', () => 'application/json');
    }

    final uri = Uri.parse(request.url);
    final effectiveTimeout = request.timeout ?? timeout;

    late final http.Response response;
    switch (request.method.toUpperCase()) {
      case 'GET':
        response = await _client.get(uri, headers: headers).timeout(effectiveTimeout);
      case 'POST':
        response = await _client
            .post(uri, headers: headers, body: encodedBody)
            .timeout(effectiveTimeout);
      case 'PATCH':
        response = await _client
            .patch(uri, headers: headers, body: encodedBody)
            .timeout(effectiveTimeout);
      case 'DELETE':
        response = await _client
            .delete(uri, headers: headers, body: encodedBody)
            .timeout(effectiveTimeout);
      default:
        throw ArgumentError('Unsupported HTTP method: ${request.method}');
    }

    final contentType = response.headers['content-type'] ?? '';
    dynamic data;
    if (contentType.contains('application/json') && response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        data = response.body;
      }
    } else if (response.body.isNotEmpty) {
      data = response.body;
    }

    return HttpResponse(
      status: response.statusCode,
      statusText: response.reasonPhrase ?? '',
      headers: response.headers,
      data: data,
    );
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

FetchAdapter createFetchAdapter({
  Duration timeout = const Duration(milliseconds: 30000),
  http.Client? client,
}) {
  return FetchAdapter(timeout: timeout, client: client);
}
