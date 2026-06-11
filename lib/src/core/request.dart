import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../adapters/http/types.dart';
import '../errors/sdk_error.dart';
import '../models/request_result.dart';
import 'config.dart';

const String storageKeyToken = 'vp:token';
const String storageKeyMeta = 'vp:auth_meta';
const String storageKeyUser = 'vp:auth_user';
const String storageKeyDeviceId = 'vp:device_id';

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
      await storage.removeItemAsync(storageKeyUser);
      return;
    }

    storage.removeItem(storageKeyToken);
    storage.removeItem(storageKeyMeta);
    storage.removeItem(storageKeyUser);
  }

  Future<Map<String, dynamic>?> getAuthMeta() async {
    final storage = config.storage;
    final String? metaJson;
    if (storage.isAsync) {
      metaJson = await storage.getItemAsync(storageKeyMeta);
    } else {
      metaJson = storage.getItem(storageKeyMeta);
    }

    if (metaJson == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(metaJson));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUser() async {
    final storage = config.storage;
    final String? userJson;
    if (storage.isAsync) {
      userJson = await storage.getItemAsync(storageKeyUser);
    } else {
      userJson = storage.getItem(storageKeyUser);
    }

    if (userJson == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(userJson));
    } catch (_) {
      return null;
    }
  }

  Future<void> setUser(Map<String, dynamic> user) async {
    final storage = config.storage;
    final userJson = _encodeJson(user);
    if (storage.isAsync) {
      await storage.setItemAsync(storageKeyUser, userJson);
      return;
    }
    storage.setItem(storageKeyUser, userJson);
  }

  Future<String> getDeviceId() async {
    if (config.deviceId != null && config.deviceId!.isNotEmpty) {
      return config.deviceId!;
    }

    final storage = config.storage;
    String? deviceId;
    if (storage.isAsync) {
      deviceId = await storage.getItemAsync(storageKeyDeviceId);
    } else {
      deviceId = storage.getItem(storageKeyDeviceId);
    }

    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _generateUuid();
      if (storage.isAsync) {
        await storage.setItemAsync(storageKeyDeviceId, deviceId);
      } else {
        storage.setItem(storageKeyDeviceId, deviceId);
      }
    }

    return deviceId;
  }

  String _generateUuid() {
    final random = math.Random();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.split('').map((c) {
      if (c == 'x') {
        final r = random.nextInt(16);
        return r.toRadixString(16);
      } else if (c == 'y') {
        final r = random.nextInt(16) & 0x3 | 0x8;
        return r.toRadixString(16);
      } else {
        return c;
      }
    }).join();
  }

  String _getDefaultUserAgent() {
    final platformName = kIsWeb ? 'Web' : defaultTargetPlatform.name;
    return 'Veloquent Dart SDK/1.4.0 ($platformName)';
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

    final deviceId = await getDeviceId();
    headers['X-Device-ID'] = deviceId;
    headers['User-Agent'] = config.userAgent ?? _getDefaultUserAgent();

    final serializedBody = serializeDates(body);

    try {
      final response = await config.http.request(
        HttpRequest(
          url: url,
          method: method,
          body: serializedBody,
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
            data: parseDates(map['data']),
            meta: map['meta'] is Map
                ? Map<String, dynamic>.from(map['meta'])
                : null,
            message: map['message']?.toString(),
          );
        }
      }

      return RequestResult<dynamic>(data: parseDates(responseData));
    } catch (error) {
      if (error is SdkError) {
        rethrow;
      }
      throw SdkError('REQUEST_FAILED', _errorMessage(error), cause: error);
    }
  }

  Stream<List<int>> executeStream({
    required String method,
    required String path,
    dynamic body,
    Map<String, dynamic>? query,
  }) async* {
    final url = buildUrl('${config.apiUrl}/api', path, query);
    final headers = <String, String>{};

    final token = await getToken();
    if (token != null && token.trim().isNotEmpty) {
      headers['authorization'] = 'Bearer $token';
    }

    final deviceId = await getDeviceId();
    headers['X-Device-ID'] = deviceId;

    headers['User-Agent'] = config.userAgent ?? _getDefaultUserAgent();

    final serializedBody = serializeDates(body);

    try {
      final stream = config.http.requestStream(
        HttpRequest(
          url: url,
          method: method,
          body: serializedBody,
          headers: headers,
          timeout: config.timeout,
        ),
      );
      yield* stream;
    } on HttpResponse catch (response) {
      throw errorFromResponse(response);
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
    String? apiCode;

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      message = (map['message']?.toString().trim().isNotEmpty ?? false)
          ? map['message'].toString()
          : (map['error']?.toString() ?? message);
      details = map['errors'] ?? map;
      apiCode = map['code']?.toString() ?? map['error_type']?.toString();
    }

    var code = 'HTTP_ERROR';
    if (apiCode != null && apiCode.isNotEmpty) {
      code = apiCode;
    } else {
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

dynamic serializeDates(dynamic obj) {
  if (obj == null) return null;
  if (obj is DateTime) {
    return obj.toUtc().toIso8601String();
  }
  if (obj is List<int>) {
    return obj;
  }
  if (obj is List) {
    return obj.map((e) => serializeDates(e)).toList();
  }
  if (obj is Map) {
    return Map<String, dynamic>.fromEntries(
      obj.entries.map(
        (entry) => MapEntry(entry.key.toString(), serializeDates(entry.value)),
      ),
    );
  }
  return obj;
}

dynamic parseDates(dynamic obj) {
  if (obj == null) return null;
  if (obj is String) {
    final regExp = RegExp(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}');
    if (regExp.hasMatch(obj)) {
      var normalized = obj;
      if (!RegExp(r'[Zz]$').hasMatch(normalized) &&
          !RegExp(r'[+-]\d{2}(:?\d{2})?$').hasMatch(normalized)) {
        normalized = '${normalized.replaceAll(' ', 'T')}Z';
      }
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) {
        return parsed.toLocal();
      }
    }
    return obj;
  }
  if (obj is List) {
    return obj.map((e) => parseDates(e)).toList();
  }
  if (obj is Map) {
    return Map<String, dynamic>.fromEntries(
      obj.entries.map(
        (entry) => MapEntry(entry.key.toString(), parseDates(entry.value)),
      ),
    );
  }
  return obj;
}
