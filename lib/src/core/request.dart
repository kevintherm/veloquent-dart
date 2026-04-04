import 'dart:convert';

import '../adapters/http/types.dart';
import '../errors/sdk_error.dart';
import '../models/request_result.dart';
import 'config.dart';

const String storageKeyToken = 'vp:token';
const String storageKeyMeta = 'vp:auth_meta';

String buildUrl(String baseUrl, String path, [Map<String, dynamic>? params]) {
  final baseUri = Uri.parse('$baseUrl$path');
  if (params == null || params.isEmpty) {
    return baseUri.toString();
  }

  final queryParams = <String, String>{};
  for (final entry in params.entries) {
    final value = entry.value;
    if (value != null) {
      queryParams[entry.key] = '$value';
    }
  }

  final mergedParams = <String, String>{
    ...baseUri.queryParameters,
    ...queryParams,
  };

  return baseUri.replace(queryParameters: mergedParams).toString();
}

class RequestHelper {
  RequestHelper(this.config);

  final VeloquentConfig config;

  Future<String?> getToken() async {
    final storage = config.storage;
    if (storage.isAsync) {
      return storage.getItemAsync(storageKeyToken);
    }
    return storage.getItem(storageKeyToken);
  }

  Future<void> setToken(String token, [Map<String, dynamic>? meta]) async {
    final storage = config.storage;
    if (storage.isAsync) {
      await storage.setItemAsync(storageKeyToken, token);
      if (meta != null) {
        await storage.setItemAsync(storageKeyMeta, _encodeJson(meta));
      }
      return;
    }

    storage.setItem(storageKeyToken, token);
    if (meta != null) {
      storage.setItem(storageKeyMeta, _encodeJson(meta));
    }
  }

  Future<void> clearToken() async {
    final storage = config.storage;
    if (storage.isAsync) {
      await storage.removeItemAsync(storageKeyToken);
      await storage.removeItemAsync(storageKeyMeta);
      return;
    }

    storage.removeItem(storageKeyToken);
    storage.removeItem(storageKeyMeta);
  }

  Future<RequestResult<dynamic>> execute({
    required String method,
    required String path,
    dynamic body,
    Map<String, dynamic>? query,
  }) async {
    final url = buildUrl('${config.apiUrl}/api', path, query);
    final headers = <String, String>{};

    final token = await getToken();
    if (token != null && token.trim().isNotEmpty) {
      headers['authorization'] = 'Bearer $token';
    }

    try {
      final response = await config.http.request(
        HttpRequest(
          url: url,
          method: method,
          body: body,
          headers: headers,
          timeout: config.timeout,
        ),
      );

      if (response.status >= 400) {
        throw errorFromResponse(response);
      }

      final responseData = response.data;
      if (responseData is Map) {
        final map = Map<String, dynamic>.from(responseData);
        if (map.containsKey('data')) {
          return RequestResult<dynamic>(
            data: map['data'],
            meta: map['meta'] is Map ? Map<String, dynamic>.from(map['meta']) : null,
            message: map['message']?.toString(),
          );
        }
      }

      return RequestResult<dynamic>(data: responseData);
    } catch (error) {
      if (error is SdkError) {
        rethrow;
      }
      throw SdkError('REQUEST_FAILED', _errorMessage(error), cause: error);
    }
  }

  SdkError errorFromResponse(HttpResponse response) {
    final status = response.status;
    final data = response.data;

    String message = 'Unknown error';
    dynamic details = data;

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      message = (map['message']?.toString().trim().isNotEmpty ?? false)
          ? map['message'].toString()
          : (map['error']?.toString() ?? message);
      details = map['errors'] ?? map;
    }

    var code = 'HTTP_ERROR';
    if (status == 400) {
      code = 'BAD_REQUEST';
    } else if (status == 401) {
      code = 'UNAUTHORIZED';
    } else if (status == 403) {
      code = 'FORBIDDEN';
    } else if (status == 404) {
      code = 'NOT_FOUND';
    } else if (status == 409) {
      code = 'CONFLICT';
    } else if (status == 422) {
      code = 'VALIDATION_ERROR';
    } else if (status >= 500) {
      code = 'SERVER_ERROR';
    }

    return SdkError(code, message, statusCode: status, details: details);
  }
}

String _encodeJson(Map<String, dynamic> value) {
  return jsonEncode(value);
}

String _errorMessage(Object error) {
  if (error is TypeError) {
    return error.toString();
  }
  final message = error.toString();
  if (message.startsWith('Exception: ')) {
    return message.substring('Exception: '.length);
  }
  return message;
}
