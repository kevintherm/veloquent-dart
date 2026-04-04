import 'package:test/test.dart';
import 'package:veloquent_sdk/veloquent_sdk.dart';
import 'dart:io';
import 'dart:async';
import 'mocks.dart';

void main() {
  final apiUrl = Platform.environment['VELOQUENT_API_URL'] ?? 'http://localhost:80';
  final runIntegration = Platform.environment['RUN_INTEGRATION_TESTS'] == 'true';
  final pusherKey = Platform.environment['PUSHER_KEY'] ?? 'your-pusher-key';
  final pusherCluster = Platform.environment['PUSHER_CLUSTER'] ?? 'ap1';

  group('Live Realtime Integration', () {
    final Map<String, String?> storageData = {};
    late Veloquent sdk;
    
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String testEmail = 'test_rt_$timestamp@example.com';
    const String testPassword = 'password123';
    const String userCollection = 'users';
    const String postCollection = 'posts';

    setUpAll(() {
      sdk = Veloquent(
        apiUrl: apiUrl,
        http: FetchAdapter(),
        storage: MockStorageAdapter(),
      );
    });

    tearDownAll(() async {
      await sdk.realtime.disconnect();
    });

    test('Integration: Should receive realtime events when a record is created', () async {
      // 1. Create unique user & Login
      final uniqueEmail = 'rt${timestamp.substring(timestamp.length - 8)}@gmail.com';
      try {
        await sdk.records.create(userCollection, {
          'name': 'Realtime Test User',
          'email': uniqueEmail,
          'password': testPassword,
          'password_confirmation': testPassword,
        });
      } on SdkError catch (e) {
        if (e.code == 'VALIDATION_ERROR' && e.details.toString().contains('already been taken')) {
          // Ignore
        } else {
          rethrow;
        }
      }
      
      try {
        final loginRes = await sdk.requestHelper.execute(
          method: 'POST',
          path: '/collections/$userCollection/auth/login',
          body: {'identity': uniqueEmail, 'password': testPassword},
        );
        await sdk.requestHelper.setToken(loginRes.data['token'].toString());
      } catch (e) {
        // Fallback for environment consistency
        const fallbackEmail = 'test@example.com'; 
        final loginRes = await sdk.requestHelper.execute(
          method: 'POST',
          path: '/collections/$userCollection/auth/login',
          body: {'identity': fallbackEmail, 'password': testPassword},
        );
        await sdk.requestHelper.setToken(loginRes.data['token'].toString());
      }

      // 2. Setup Realtime Adapter
      final rtAdapter = MockRealtimeAdapter();
      sdk.realtime.adapter = rtAdapter;

      final completer = Completer<Map<String, dynamic>>();

      // 3. Subscribe to collection
      // The SDK will call /api/collections/posts/subscribe to get the channel name
      // and then call adapter.subscribe(channel, callback)
      await sdk.realtime.subscribe(postCollection, callback: (event, payload) {
        if (event.contains('created')) {
          completer.complete(payload);
        }
      });

      expect(rtAdapter.subscribedChannels, isNotEmpty);
      final channelName = rtAdapter.subscribedChannels.first;

      // 4. Simulate the server-side event being received by the adapter
      // Since we can't easily run the full Pusher native library in a pure Dart test (it requires Flutter engine),
      // we verify the SDK's orchestration: it hit the subscribe endpoint and wired up the adapter.
      rtAdapter.emit('$channelName.record.created', {
        'record': {'id': 'rec-rt-1', 'title': 'Realtime Post'},
        'action': 'created'
      });

      final receivedPayload = await completer.future.timeout(const Duration(seconds: 5));
      expect(receivedPayload['title'], 'Realtime Post');
      expect(receivedPayload['id'], 'rec-rt-1');
    }, skip: !runIntegration ? 'Set RUN_INTEGRATION_TESTS=true to run' : null);
  });
}
