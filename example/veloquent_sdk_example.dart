import 'package:veloquent_sdk/veloquent_sdk.dart';
// import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

void main() async {
  // 1. Initialize SDK
  // In a real Flutter app, LocalStorageAdapter needs await SharedPreferences.getInstance()
  
  /*
  final sdk = Veloquent(
    apiUrl: 'https://example.com',
    http: createFetchAdapter(),
    storage: await createLocalStorageAdapter(), 
  );

  print('Veloquent SDK Initialized');

  // 2. Auth Example
  try {
    final loginRes = await sdk.auth.login('users', 'test@example.com', 'password');
    print('Logged in: ${loginRes['token']}');

    final isAuthenticated = await sdk.auth.isAuthenticated();
    print('Is authenticated: $isAuthenticated');

    // 3. Records Example
    final posts = await sdk.records.list('posts', filter: 'status="published"', perPage: 10);
    print('Fetched ${posts.data.length} posts');

    // 4. Realtime Example (Requires Pusher setup)
    /*
    final pusher = PusherChannelsFlutter.getInstance();
    await pusher.init(
      apiKey: 'YOUR_APP_KEY',
      cluster: 'YOUR_CLUSTER',
      authEndpoint: 'https://example.com/api/broadcasting/auth',
      authParams: {
        'headers': {
          'Authorization': 'Bearer ${loginRes['token']}'
        }
      }
    );
    
    final realtimeAdapter = createPusherChannelsAdapter(pusher);
    sdk.realtime.adapter = realtimeAdapter;

    await sdk.realtime.subscribe('posts', (event, payload) {
      print('Realtime event: $event - ${payload['id']}');
    });
    */

    // 5. Cleanup
    await sdk.auth.logout('users');
    print('Logged out');

  } catch (e) {
    if (e is SdkError) {
      print('SDK Error: ${e.code} - ${e.message}');
    } else {
      print('Unexpected error: $e');
    }
  }
  */
}
