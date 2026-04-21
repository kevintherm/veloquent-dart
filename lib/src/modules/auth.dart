import '../core/request.dart';

class Auth {
  Auth(this.requestHelper);

  final RequestHelper requestHelper;

  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? _session;

  /// Returns the currently authenticated user record, if any.
  Map<String, dynamic>? get user => _currentUser;

  /// Returns the current session metadata (token, collection, etc).
  Map<String, dynamic>? get session => _session;

  /// Loads the authenticated state from storage.
  /// Should be called during SDK initialization.
  Future<void> loadState() async {
    _currentUser = await requestHelper.getUser();
    _session = await requestHelper.getAuthMeta();
  }


  Future<Map<String, dynamic>> login(
      String collection, String identity, String password) async {
    final result = await requestHelper.execute(
      method: 'POST',
      path: '/collections/$collection/auth/login',
      body: {'identity': identity, 'password': password},
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
      _session = meta;

      if (data.containsKey('record')) {
        final record = Map<String, dynamic>.from(data['record']);
        await requestHelper.setUser(record);
        _currentUser = record;
      }
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
      _session = meta;

      if (responseData.containsKey('record')) {
        final record = Map<String, dynamic>.from(responseData['record']);
        await requestHelper.setUser(record);
        _currentUser = record;
      }
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
      _session = meta;

      if (data.containsKey('record')) {
        final record = Map<String, dynamic>.from(data['record']);
        await requestHelper.setUser(record);
        _currentUser = record;
      }
    }


    return data;
  }

  Future<void> logout(String collection) async {
    try {
      await requestHelper.execute(
        method: 'DELETE',
        path: '/collections/$collection/auth/logout',
      );
    } finally {
      await requestHelper.clearToken();
      _currentUser = null;
      _session = null;
    }
  }

  Future<void> logoutAll(String collection) async {
    try {
      await requestHelper.execute(
        method: 'DELETE',
        path: '/collections/$collection/auth/logout-all',
      );
    } finally {
      await requestHelper.clearToken();
      _currentUser = null;
      _session = null;
    }
  }


  Future<dynamic> me([String? collection]) async {
    final path = collection != null ? '/collections/$collection/auth/me' : '/user';

    final result = await requestHelper.execute(
      method: 'GET',
      path: path,
    );

    final userData = Map<String, dynamic>.from(result.data);
    await requestHelper.setUser(userData);
    _currentUser = userData;

    return result.data;
  }


  Future<bool> isAuthenticated() async {
    final token = await requestHelper.getToken();
    return token != null && token.trim().isNotEmpty;
  }
}
