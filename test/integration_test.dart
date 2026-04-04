import 'package:test/test.dart';
import 'package:veloquent_sdk/veloquent_sdk.dart';
import 'dart:io';

void main() {
  final apiUrl = Platform.environment['VELOQUENT_API_URL'] ?? 'http://localhost:80';
  final runIntegration = Platform.environment['RUN_INTEGRATION_TESTS'] == 'true';

  group('Live Server Integration', () {
    final Map<String, String?> storageData = {};
    final mockStorage = MockStorageAdapter(storageData);
    String? userId;
    
    final sdk = Veloquent(
      apiUrl: apiUrl,
      http: FetchAdapter(),
      storage: mockStorage,
    );

    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String testEmail = 'test$timestamp@gmail.com';
    const String testPassword = 'password123';
    const String userCollection = 'users';
    const String postCollection = 'posts';

    test('Integration: Should create a user and login', () async {
      try {
        final createdUser = await sdk.records.create(userCollection, {
          'name': 'Integration Test User',
          'email': testEmail,
          'password': testPassword,
          'password_confirmation': testPassword,
        });

        userId = createdUser.id;
        expect(createdUser.id, isNotNull);
        expect(createdUser.get('email'), testEmail);

        final loginRes = await sdk.requestHelper.execute(
          method: 'POST',
          path: '/collections/$userCollection/auth/login',
          body: {'identity': testEmail, 'password': testPassword},
        );
        expect(loginRes.data['token'], isNotNull);
        await sdk.requestHelper.setToken(loginRes.data['token'].toString());
        expect(await sdk.auth.isAuthenticated(), isTrue);

        final profile = await sdk.auth.me(userCollection);
        expect(profile['email'], testEmail);
      } catch (e) {
        if (e is SdkError) {
          print('USER VALIDATION ERROR DETAILS: ${e.details}');
        }
        rethrow;
      }
    }, skip: !runIntegration ? 'Set RUN_INTEGRATION_TESTS=true to run' : null);

    test('Integration: Should perform CRUD on posts collection', () async {
      try {
        final String title = 'Integration Post $timestamp';
        print('DEBUG: userId is $userId');

        final createdPost = await sdk.records.create(postCollection, {
          'title': title,
          'content': 'Created by Dart integration test',
          'user': userId,
          'published': true,
        });
        expect(createdPost.id, isNotNull);
        expect(createdPost.get('title'), title);

        final listResult = await sdk.records.list(postCollection, 
          filter: 'title = "$title"'
        );
        expect(listResult.data.length, greaterThan(0));
        expect(listResult.data.first.id, createdPost.id);

        final updatedPost = await sdk.records.update(postCollection, createdPost.id!, {
          'title': '$title (Updated)',
        });
        expect(updatedPost.get('title'), contains('(Updated)'));

        await sdk.records.delete(postCollection, createdPost.id!);
        
        final verifyList = await sdk.records.list(postCollection, 
          filter: 'id = "${createdPost.id}"'
        );
        expect(verifyList.data.isEmpty, isTrue);
      } catch (e) {
        if (e is SdkError) {
          print('POSTS VALIDATION ERROR DETAILS: ${e.details}');
        }
        rethrow;
      }
    }, skip: !runIntegration ? 'Set RUN_INTEGRATION_TESTS=true to run' : null);
  });
}

class MockStorageAdapter extends StorageAdapter {
  MockStorageAdapter(this.data);
  final Map<String, String?> data;

  @override
  bool get isAsync => false;

  @override
  String? getItem(String key) => data[key];

  @override
  void setItem(String key, String value) => data[key] = value;

  @override
  void removeItem(String key) => data.remove(key);

  @override
  void clear() => data.clear();

  @override
  Future<void> clearAsync() async => clear();
  @override
  Future<String?> getItemAsync(String key) async => getItem(key);
  @override
  Future<void> removeItemAsync(String key) async => removeItem(key);
  @override
  Future<void> setItemAsync(String key, String value) async => setItem(key, value);
}
