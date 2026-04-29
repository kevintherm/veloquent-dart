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
        'identity': 'test@example.com',
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
      expect(sdk.auth.user, isNull);
      expect(sdk.auth.session, isNull);
      
      final req = httpAdapter.lastRequest;
      expect(req?['method'], 'DELETE');
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

    test('maintains synchronous user and session state', () async {
      final mockUser = {'id': '1', 'email': 'test@example.com'};
      final mockMeta = {
        'expires_in': 3600,
        'collection_name': 'users',
        'issued_at': '2026-01-01T00:00:00Z'
      };

      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {
          'token': 'sync-token',
          'record': mockUser,
          ...mockMeta,
        }
      });

      await sdk.auth.login('users', 'test@example.com', 'password');

      expect(sdk.auth.user, equals(mockUser));
      expect(sdk.auth.session?['collection_name'], 'users');
      expect(storageAdapter.getItem('vp:auth_user'), contains('test@example.com'));
    });

    test('getOAuthRedirectUrl hits /api/oauth2/redirect', () async {
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {'redirect_url': 'http://localhost/oauth/redirect'}
      });

      final url = await sdk.auth.getOAuthRedirectUrl('users', 'google');

      expect(url, 'http://localhost/oauth/redirect');
      final req = httpAdapter.lastRequest;
      expect(req?['method'], 'POST');
      expect(req?['url'], 'http://localhost:3000/api/oauth2/redirect');
      expect(req?['body'], {'collection': 'users', 'provider': 'google'});
    });

    test('exchangeOAuthCode hits /api/oauth2/exchange and stores session', () async {
      final mockUser = {'id': 'user-123', 'email': 'oauth@example.com'};
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {
          'token': 'oauth-token',
          'expires_in': 3600,
          'collection_name': 'users',
          'record': mockUser
        }
      });

      final result = await sdk.auth.exchangeOAuthCode('some-code');

      expect(result['token'], 'oauth-token');
      expect(sdk.auth.user, equals(mockUser));
      expect(storageAdapter.getItem('vp:token'), 'oauth-token');

      final req = httpAdapter.lastRequest;
      expect(req?['method'], 'POST');
      expect(req?['url'], 'http://localhost:3000/api/oauth2/exchange');
      expect(req?['body'], {'code': 'some-code'});
    });

    test('loginWithOAuth coordinates with launcher adapter', () async {
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {'redirect_url': 'http://localhost/oauth'}
      });

      // Second response for the code exchange
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {
          'token': 'oauth-token',
          'expires_in': 3600,
          'collection_name': 'users',
          'record': {'email': 'oauth@example.com'}
        }
      });

      Future<String> mockLauncher(String url) async {
        expect(url, 'http://localhost/oauth');
        return 'extracted-code';
      }

      final result = await sdk.auth.loginWithOAuth('users', 'google', mockLauncher);

      expect(result['token'], 'oauth-token');
      expect(sdk.auth.user?['email'], 'oauth@example.com');
    });
  });
}

