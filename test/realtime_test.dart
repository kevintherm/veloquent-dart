import 'package:test/test.dart';
import 'package:veloquent_sdk/veloquent_sdk.dart';
import 'mocks.dart';

void main() {
  group('Realtime', () {
    late MockHttpAdapter httpAdapter;
    late MockRealtimeAdapter realtimeAdapter;
    late Veloquent sdk;

    setUp(() {
      httpAdapter = MockHttpAdapter();
      realtimeAdapter = MockRealtimeAdapter();
      sdk = Veloquent(
        apiUrl: 'http://localhost:3000',
        http: httpAdapter,
        storage: MockStorageAdapter(),
        realtime: realtimeAdapter,
      );
    });

    test('subscribe calls adapter and triggers callback with flattened payload', () async {
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {'channel': 'private-posts'}
      });

      final List<Map<String, dynamic>> receivedPayloads = [];
      final List<String> receivedEvents = [];

      await sdk.realtime.subscribe('posts', callback: (event, payload) {
        receivedEvents.add(event);
        receivedPayloads.add(payload);
      });

      expect(realtimeAdapter.lastChannelName, 'posts');

      // Simulate a pusher event
      realtimeAdapter.emit('posts.record.created', {
        'record': {'id': 'rec-1', 'title': 'Test Post'},
        'action': 'created'
      });

      expect(receivedPayloads[0]['title'], 'Test Post');
      expect(receivedPayloads[0]['id'], 'rec-1');
    });

    test('subscribe without adapter throws error', () async {
      final sdkNoAdapter = Veloquent(
        apiUrl: 'http://localhost:3000',
        http: MockHttpAdapter(),
        storage: MockStorageAdapter(),
      );

      expect(
        () => sdkNoAdapter.realtime.subscribe('posts'),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('Realtime adapter is not configured'))),
      );
    });

    test('unsubscribe calls adapter', () async {
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {'channel': 'private-posts'}
      });
      await sdk.realtime.subscribe('posts');

      await sdk.realtime.disconnect();
      expect(realtimeAdapter.unsubscribedChannels, contains('posts'));
    });
  });
}
