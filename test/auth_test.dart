import 'package:test/test.dart';
import 'package:veloquent_sdk/veloquent_sdk.dart';
import 'mocks.dart';

void main() {
  group('Auth', () {
    late MockHttpAdapter httpAdapter;
    late MockStorageAdapter storageAdapter;
    late Veloquent sdk;

    setUp(() {
      httpAdapter = MockHttpAdapter();
      storageAdapter = MockStorageAdapter();
      sdk = Veloquent(
        apiUrl: 'http://localhost:3000',
        http: httpAdapter,
        storage: storageAdapter,
      );
    });

    test('login stores token in storage', () async {
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {
          'token': 'mock-token',
          'expires_in': 3600,
          'collection_name': 'users'
        }
      });

      final result = await sdk.auth.login('users', 'test@example.com', 'password');

      expect(result['token'], 'mock-token');
      expect(storageAdapter.getItem('vp:token'), 'mock-token');
    });

    test('login endpoint is correct', () async {
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {
          'token': 'token123',
          'expires_in': 3600,
          'collection_name': 'users'
        }
      });

      await sdk.auth.login('users', 'test@example.com', 'password');

      final req = httpAdapter.lastRequest;
      expect(req?['method'], 'POST');
      expect(req?['url'], 'http://localhost:3000/api/collections/users/auth/login');
      expect(req?['body'], {
        'email': 'test@example.com',
        'password': 'password'
      });
    });

    test('impersonate stores the returned token', () async {
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {
          'token': 'impersonation-token',
          'expires_in': 3600,
          'collection_name': 'users'
        }
      });

      final result = await sdk.auth.impersonate('users', 'rec-123');

      expect(result['token'], 'impersonation-token');
      expect(storageAdapter.getItem('vp:token'), 'impersonation-token');

      final req = httpAdapter.lastRequest;
      expect(req?['method'], 'POST');
      expect(req?['url'], 'http://localhost:3000/api/collections/users/auth/impersonate/rec-123');
    });

    test('logout clears token', () async {
      storageAdapter.setItem('vp:token', 'test-token');
      
      httpAdapter.mockResponse(200, {'message': 'Logged out'});

      await sdk.auth.logout('users');

      expect(storageAdapter.getItem('vp:token'), isNull);
      
      final req = httpAdapter.lastRequest;
      expect(req?['method'], 'POST');
      expect(req?['url'], 'http://localhost:3000/api/collections/users/auth/logout');
    });

    test('me returns user data', () async {
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {'id': '1', 'email': 'test@example.com'}
      });

      final result = await sdk.auth.me('users');

      expect(result['id'], '1');
      expect(result['email'], 'test@example.com');
      
      final req = httpAdapter.lastRequest;
      expect(req?['url'], 'http://localhost:3000/api/collections/users/auth/me');
    });

    test('isAuthenticated returns true when token exists', () async {
      storageAdapter.setItem('vp:token', 'some-token');
      expect(await sdk.auth.isAuthenticated(), isTrue);
    });

    test('isAuthenticated returns false when token missing', () async {
      expect(await sdk.auth.isAuthenticated(), isFalse);
    });
  });
}
