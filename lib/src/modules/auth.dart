import '../core/request.dart';
import '../models/request_result.dart';

class Auth {
  Auth(this.requestHelper);

  final RequestHelper requestHelper;

  Future<Map<String, dynamic>> login(
      String collection, String email, String password) async {
    final result = await requestHelper.execute(
      method: 'POST',
      path: '/collections/$collection/auth/login',
      body: {'email': email, 'password': password},
    );

    final data = Map<String, dynamic>.from(result.data);
    final token = data['token']?.toString();
    if (token != null) {
      final meta = <String, dynamic>{
        'expires_in': data['expires_in'],
        'collection_name': data['collection_name'],
        'issued_at': DateTime.now().toIso8601String(),
      };

      await requestHelper.setToken(token, meta);
    }

    return data;
  }

  Future<Map<String, dynamic>> register(
      String collection, Map<String, dynamic> data) async {
    final result = await requestHelper.execute(
      method: 'POST',
      path: '/collections/$collection/auth/register',
      body: data,
    );

    final responseData = Map<String, dynamic>.from(result.data);
    final token = responseData['token']?.toString();
    if (token != null) {
      final meta = <String, dynamic>{
        'expires_in': responseData['expires_in'],
        'collection_name': responseData['collection_name'],
        'issued_at': DateTime.now().toIso8601String(),
      };

      await requestHelper.setToken(token, meta);
    }

    return responseData;
  }

  Future<Map<String, dynamic>> impersonate(
      String collection, String recordId) async {
    final result = await requestHelper.execute(
      method: 'POST',
      path: '/collections/$collection/auth/impersonate/$recordId',
    );

    final data = Map<String, dynamic>.from(result.data);
    final token = data['token']?.toString();
    if (token != null) {
      final meta = <String, dynamic>{
        'expires_in': data['expires_in'],
        'collection_name': data['collection_name'],
        'issued_at': DateTime.now().toIso8601String(),
      };

      await requestHelper.setToken(token, meta);
    }

    return data;
  }

  Future<void> logout(String collection) async {
    try {
      await requestHelper.execute(
        method: 'POST',
        path: '/collections/$collection/auth/logout',
      );
    } finally {
      await requestHelper.clearToken();
    }
  }

  Future<void> logoutAll(String collection) async {
    try {
      await requestHelper.execute(
        method: 'POST',
        path: '/collections/$collection/auth/logout-all',
      );
    } finally {
      await requestHelper.clearToken();
    }
  }

  Future<dynamic> me([String? collection]) async {
    final path = collection != null ? '/collections/$collection/auth/me' : '/user';

    final result = await requestHelper.execute(
      method: 'GET',
      path: path,
    );

    return result.data;
  }

  Future<bool> isAuthenticated() async {
    final token = await requestHelper.getToken();
    return token != null && token.trim().isNotEmpty;
  }
}
