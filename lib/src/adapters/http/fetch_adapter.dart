import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/file_upload.dart';
import 'types.dart';

/// Returns true if the given body map contains at least one [FileUpload] value.
bool _hasFileUploads(dynamic body) {
  if (body is! Map) return false;
  return body.values.any((v) =>
      v is FileUpload ||
      (v is List && v.any((e) => e is FileUpload)));
}

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

    if (_hasFileUploads(request.body)) {
      return _requestMultipart(request, headers);
    }

    return _requestJson(request, headers);
  }

  /// Standard JSON request path.
  Future<HttpResponse> _requestJson(HttpRequest request, Map<String, String> headers) async {
    Object? encodedBody;
    if (request.body != null) {
      if (request.body is String) {
        encodedBody = request.body as String;
      } else {
        encodedBody = jsonEncode(request.body);
      }
      headers.putIfAbsent('content-type', () => 'application/json');
    }

    return sendJsonRequest(
      method: request.method.toUpperCase(),
      uri: Uri.parse(request.url),
      encodedBody: encodedBody,
      headers: headers,
      timeout: request.timeout ?? timeout,
      originalBody: request.body,
    );
  }

  /// Executes the prepared JSON request and returns the parsed response.
  /// Subclasses or test adapters can override this to intercept JSON calls.
  Future<HttpResponse> sendJsonRequest({
    required String method,
    required Uri uri,
    required Object? encodedBody,
    required Map<String, String> headers,
    required Duration timeout,
    dynamic originalBody,
  }) async {
    late final http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers).timeout(timeout);
      case 'POST':
        response = await _client
            .post(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
      case 'PATCH':
        response = await _client
            .patch(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
      case 'DELETE':
        response = await _client
            .delete(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    return _parseResponse(response);
  }

  /// Multipart request path, used when the body contains [FileUpload] values.
  ///
  /// All non-file values are appended as regular fields (JSON-encoded if
  /// they are maps or lists). File values are appended as bytes.
  /// The `+` and `-` key suffixes for append/remove operations pass through
  /// unchanged — the backend understands them natively.
  Future<HttpResponse> _requestMultipart(HttpRequest request, Map<String, String> headers) async {
    final uri = Uri.parse(request.url);
    final multipartRequest = http.MultipartRequest(request.method.toUpperCase(), uri);

    multipartRequest.headers.addAll(headers);

    final body = request.body as Map;
    final capturedFiles = <Map<String, dynamic>>[];

    for (final entry in body.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (value == null) continue;

      if (value is FileUpload) {
        multipartRequest.files.add(
          http.MultipartFile.fromBytes(
            key,
            value.bytes,
            filename: value.filename,
            contentType: _parseMediaType(value.mimeType),
          ),
        );
        capturedFiles.add({'field': key, 'filename': value.filename, 'mimeType': value.mimeType});
        continue;
      }

      if (value is List) {
        for (final item in value) {
          if (item is FileUpload) {
            multipartRequest.files.add(
              http.MultipartFile.fromBytes(
                key,
                item.bytes,
                filename: item.filename,
                contentType: _parseMediaType(item.mimeType),
              ),
            );
            capturedFiles.add({'field': key, 'filename': item.filename, 'mimeType': item.mimeType});
          } else {
            multipartRequest.fields[key] = item is Map || item is List
                ? jsonEncode(item)
                : item.toString();
          }
        }
        continue;
      }

      if (value is Map || value is List) {
        multipartRequest.fields[key] = jsonEncode(value);
        continue;
      }

      multipartRequest.fields[key] = value.toString();
    }

    return sendMultipartRequest(
      method: request.method.toUpperCase(),
      uri: uri,
      multipartRequest: multipartRequest,
      fields: multipartRequest.fields,
      files: capturedFiles,
      headers: headers,
      timeout: request.timeout ?? timeout,
    );
  }

  /// Sends the prepared [multipartRequest] and parses the response.
  /// Subclasses or test adapters can override this to intercept multipart calls.
  Future<HttpResponse> sendMultipartRequest({
    required String method,
    required Uri uri,
    required http.MultipartRequest multipartRequest,
    required Map<String, String> fields,
    required List<Map<String, dynamic>> files,
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    final streamedResponse = await multipartRequest.send().timeout(timeout);
    final response = await http.Response.fromStream(streamedResponse);
    return _parseResponse(response);
  }

  HttpResponse _parseResponse(http.Response response) {
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

  /// Parses a MIME type string into a [http.MediaType]-compatible object.
  /// Falls back to `application/octet-stream` on any parse failure.
  http.MediaType? _parseMediaType(String mimeType) {
    try {
      return http.MediaType.parse(mimeType);
    } catch (_) {
      return http.MediaType.parse('application/octet-stream');
    }
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
