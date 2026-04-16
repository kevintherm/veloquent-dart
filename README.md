# Veloquent Flutter SDK

A Flutter SDK for Veloquent BaaS, providing a high-level API for authentication, record management, collections, schema management, and real-time updates.

## Contents

- [Features](#features)
- [Installation](#installation)
- [Getting Started](#getting-started)
- [Usage](#usage)
  - [Authentication](#authentication)
  - [CRUD Operations](#crud-operations)
  - [File Uploads](#file-uploads)
  - [Real-time Subscriptions](#real-time-subscriptions)
- [Tests](#tests)
- [Contributing](#contributing)

## Features

- **Authentication**: Login, identity impersonation, logout, and session management.
- **Records**: CRUD operations on collection records with filtering, sorting, and expansion.
- **Collections**: Manage collection metadata and truncate data.
- **Schema**: Health checks and schema transfer (export/import) tools.
- **Onboarding**: Check initialization status and create initial superusers.
- **Real-time**: Subscribe to collection changes using WebSockets (via Pusher).

## Installation

Add `veloquent_sdk` to your `pubspec.yaml`:

```yaml
dependencies:
  veloquent_sdk: ^1.1.0
```

Then run:

```bash
flutter pub get
```

Package on pub.dev: [pub.dev/packages/veloquent_sdk](https://pub.dev/packages/veloquent_sdk)

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
final result = await sdk.records.list('posts',
  filter: 'status = "published"',
  sort: '-created_at',
  perPage: 25,
  page: 1,
  expand: 'authorId',
);

print(result.data);     // List<Record>
print(result.meta);     // {current_page: 1, total: 42, ...}

// Get a single record
final post = await sdk.records.get('posts', 'rec-123', expand: 'authorId');
print(post.get('title'));

// Create a record
final newPost = await sdk.records.create('posts', {
  'title': 'Hello World',
  'content': 'This is my first post',
});
print(newPost.id);

// Update a record
final updated = await sdk.records.update('posts', newPost.id, {'status': 'published'});

// Delete a record
await sdk.records.delete('posts', newPost.id);
```

### File Uploads

For collection fields of type `file`, pass a `FileUpload` object anywhere in the data map.
The SDK automatically sends the request as `multipart/form-data`, no extra setup needed.
`FileUpload` is exported from the top-level `veloquent_sdk` package.

#### Create a record with a file

```dart
final upload = FileUpload(
  bytes: imageBytes,         // List<int>
  filename: 'avatar.jpg',
  mimeType: 'image/jpeg',
);

final user = await sdk.records.create('users', {
  'name': 'Kevin',
  'avatar': upload,          // SDK detects FileUpload and sends multipart
});
```

#### Flutter — using `image_picker`

```dart
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
if (picked == null) return;

final upload = FileUpload(
  bytes: await picked.readAsBytes(),
  filename: picked.name,
  mimeType: lookupMimeType(picked.name) ?? 'application/octet-stream',
);

await sdk.records.create('photos', {'title': 'Sunset', 'image': upload});
```

#### Create with multiple files

```dart
await sdk.records.create('posts', {
  'title': 'My Trip',
  'gallery': [upload1, upload2],   // List<FileUpload>
});
```

#### Update / replace a file

```dart
await sdk.records.update('users', userId, {
  'avatar': FileUpload(bytes: newBytes, filename: 'new.jpg', mimeType: 'image/jpeg'),
});
```

#### Update / append files to a multi-file field

Suffix the field name with `+` to add files **without** replacing existing ones:

```dart
await sdk.records.update('posts', postId, {
  'gallery+': [newUpload1, newUpload2],
});
```

#### Update / remove specific files

Suffix the field name with `-` and pass a path or metadata selector:

```dart
// The path comes from the file metadata returned by the API
await sdk.records.update('posts', postId, {
  'gallery-': [{'path': 'collections/posts/abc123.jpg'}],
});
```

#### File field response shape

File fields are returned as a list of metadata maps:

```dart
final post = await sdk.records.get('posts', postId);
final gallery = post.get('gallery') as List?; // [{name, path, size, extension, mime}, ...]

// To remove by path:
final path = (gallery?.first as Map)['path'];
await sdk.records.update('posts', postId, {
  'gallery-': [{'path': path}],
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
