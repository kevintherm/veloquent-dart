# Veloquent Flutter SDK

A Flutter SDK for Veloquent BaaS, providing a high-level API for authentication, record management, collections, schema management, and real-time updates.

## Features

- **Authentication**: Login, identity impersonation, logout, and session management.
- **Records**: CRUD operations on collection records with filtering, sorting, and expansion.
- **Collections**: Manage collection metadata and truncate data.
- **Schema**: Health checks and schema transfer (export/import) tools.
- **Onboarding**: Check initialization status and create initial superusers.
- **Real-time**: Subscribe to collection changes using WebSockets (via Pusher).

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  veloquent_sdk:
    path: ../veloquent-dart # Or your git repository
  http: ^1.1.0
  shared_preferences: ^2.2.0
  pusher_channels_flutter: ^1.2.0
```

## Getting started

Initialize the SDK by providing an API URL and choosing your storage and HTTP adapters.

```dart
import 'package:veloquent_sdk/veloquent_sdk.dart';

final sdk = Veloquent(
  apiUrl: 'https://your-api.com',
  http: createFetchAdapter(),
  storage: await createLocalStorageAdapter(),
);
```

## Usage

### Authentication

```dart
final loginRes = await sdk.auth.login('users', 'user@example.com', 'password');
print('Token: ${loginRes['token']}');

final profile = await sdk.auth.me('users');
```

### CRUD Operations

```dart
// List records with filters
final posts = await sdk.records.list('posts', 
  filter: 'status = "published"', 
  sort: '-created_at'
);

// Create a record
final newPost = await sdk.records.create('posts', {
  'title': 'Hello World',
  'content': 'This is my first post',
});
```

### Real-time Subscriptions

Real-time support is provided via `pusher_channels_flutter`. You must initialize the Pusher client first.

```dart
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

final pusher = PusherChannelsFlutter.getInstance();
await pusher.init(
  apiKey: 'YOUR_KEY',
  cluster: 'YOUR_CLUSTER',
  authEndpoint: 'https://your-api.com/api/broadcasting/auth',
  authParams: {
    'headers': {
      'Authorization': 'Bearer ${token}'
    }
  }
);

// Connect the adapter to the SDK
sdk.realtime.adapter = createPusherChannelsAdapter(pusher);

// Subscribe to events
await sdk.realtime.subscribe('posts', (event, payload) {
  print('Real-time event: $event');
  print('Record: ${payload['id']}');
});
```

## Tests

Run the unit test suite with:

```bash
flutter test test/auth_test.dart test/realtime_test.dart test/records_test.dart
```

Run integration tests against a live Veloquent server with:

```bash
export RUN_INTEGRATION_TESTS=true
export VELOQUENT_API_URL=http://localhost:80
flutter test test/integration_test.dart test/integration_realtime_test.dart
```

> Note: `integration_realtime_test.dart` currently uses a mock realtime adapter to validate SDK orchestration. A full native Flutter realtime end-to-end test should be added later.

## Contributing

Contributions are welcome. Please open issues or pull requests for bug fixes, improvements, or new features. When contributing:

- Keep changes small and focused.
- Add tests for new behavior.
- Follow the existing Dart style and naming conventions.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Additional information

This SDK is designed for Flutter applications. Non-Flutter Dart targets are not officially supported for real-time features.
