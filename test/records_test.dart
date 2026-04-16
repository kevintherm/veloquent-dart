import 'package:test/test.dart';
import 'package:veloquent_sdk/veloquent_sdk.dart';
import 'mocks.dart';

void main() {
  group('Records', () {
    late MockHttpAdapter httpAdapter;
    late Veloquent sdk;

    setUp(() {
      httpAdapter = MockHttpAdapter();
      sdk = Veloquent(
        apiUrl: 'http://localhost:3000',
        http: httpAdapter,
        storage: MockStorageAdapter(),
      );
    });

    test('list fetches records', () async {
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': [
          {'id': '1', 'name': 'Post 1'},
          {'id': '2', 'name': 'Post 2'},
        ],
        'meta': {'current_page': 1, 'per_page': 10, 'total': 2}
      });

      final result = await sdk.records.list('posts');

      expect(result.data.length, 2);
      expect(result.data[0].get('name'), 'Post 1');
      expect(result.meta?['total'], 2);

      final req = httpAdapter.lastRequest;
      expect(req?['url'], 'http://localhost:3000/api/collections/posts/records');
      expect(req?['method'], 'GET');
    });

    test('list with params', () async {
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': [],
        'meta': {'current_page': 1, 'per_page': 10, 'total': 0}
      });

      await sdk.records.list('posts',
          filter: 'status="published"',
          sort: '-created_at',
          expand: 'author,category',
          page: 2,
          perPage: 5);

      final req = httpAdapter.lastRequest;
      final url = req?['url'] as String;
      expect(url, contains('filter=status%3D%22published%22'));
      expect(url, contains('sort=-created_at'));
      expect(url, contains('expand=author%2Ccategory'));
      expect(url, contains('page=2'));
      expect(url, contains('per_page=5'));
    });

    test('get fetches single record', () async {
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {'id': 'rec-123', 'name': 'The Record'}
      });

      final result = await sdk.records.get('posts', 'rec-123');

      expect(result.id, 'rec-123');

      final req = httpAdapter.lastRequest;
      expect(req?['url'], 'http://localhost:3000/api/collections/posts/records/rec-123');
    });

    test('create sends data', () async {
      httpAdapter.mockResponse(201, {
        'message': 'Created',
        'data': {'id': 'new-id', 'title': 'My Post'}
      });

      final result = await sdk.records.create('posts', {'title': 'My Post'});

      expect(result.id, 'new-id');

      final req = httpAdapter.lastRequest;
      expect(req?['method'], 'POST');
      expect(req?['body'], {'title': 'My Post'});
    });

    test('update sends partial data', () async {
      httpAdapter.mockResponse(200, {
        'message': 'Updated',
        'data': {'id': 'rec-123', 'title': 'New Title'}
      });

      final result = await sdk.records.update('posts', 'rec-123', {'title': 'New Title'});

      expect(result.get('title'), 'New Title');

      final req = httpAdapter.lastRequest;
      expect(req?['method'], 'PATCH');
      expect(req?['body'], {'title': 'New Title'});
    });

    test('delete sends DELETE request', () async {
      httpAdapter.mockResponse(200, {'message': 'Deleted'});

      await sdk.records.delete('posts', 'rec-123');

      // expect(result['message'], 'Deleted');

      final req = httpAdapter.lastRequest;
      expect(req?['method'], 'DELETE');
      expect(req?['url'], 'http://localhost:3000/api/collections/posts/records/rec-123');
    });

    // ── File upload ─────────────────────────────────────────────────

    test('create with FileUpload sends multipart request', () async {
      httpAdapter.mockResponse(201, {
        'message': 'Created',
        'data': {'id': 'rec-new', 'name': 'Kevin'},
      });

      final upload = FileUpload(
        bytes: [1, 2, 3],
        filename: 'avatar.jpg',
        mimeType: 'image/jpeg',
      );

      await sdk.records.create('users', {'name': 'Kevin', 'avatar': upload});

      final req = httpAdapter.lastRequest;
      expect(req?['method'], 'POST');
      // When multipart, the adapter records body as a MultipartRequest marker
      expect(req?['isMultipart'], isTrue);
      expect(req?['fields']?['name'], 'Kevin');
      final files = req?['files'] as List?;
      expect(files, isNotNull);
      expect(files!.any((f) => f['field'] == 'avatar' && f['filename'] == 'avatar.jpg'), isTrue);
    });

    test('create with list of FileUploads sends multipart request', () async {
      httpAdapter.mockResponse(201, {
        'message': 'Created',
        'data': {'id': 'rec-new'},
      });

      final upload1 = FileUpload(bytes: [1], filename: 'a.jpg', mimeType: 'image/jpeg');
      final upload2 = FileUpload(bytes: [2], filename: 'b.jpg', mimeType: 'image/jpeg');

      await sdk.records.create('posts', {
        'title': 'My Trip',
        'gallery': [upload1, upload2],
      });

      final req = httpAdapter.lastRequest;
      expect(req?['isMultipart'], isTrue);
      final files = req?['files'] as List?;
      expect(files!.where((f) => f['field'] == 'gallery').length, 2);
    });

    test('create with plain data sends JSON (no multipart)', () async {
      httpAdapter.mockResponse(201, {
        'message': 'Created',
        'data': {'id': 'rec-new', 'title': 'Hello'},
      });

      await sdk.records.create('posts', {'title': 'Hello', 'status': 'draft'});

      final req = httpAdapter.lastRequest;
      expect(req?['isMultipart'], isNot(isTrue));
      expect(req?['body'], {'title': 'Hello', 'status': 'draft'});
    });

    test('update with FileUpload sends multipart PATCH', () async {
      httpAdapter.mockResponse(200, {
        'message': 'Updated',
        'data': {'id': 'rec-1'},
      });

      final upload = FileUpload(bytes: [9], filename: 'new.png', mimeType: 'image/png');

      await sdk.records.update('users', 'rec-1', {'avatar': upload});

      final req = httpAdapter.lastRequest;
      expect(req?['method'], 'PATCH');
      expect(req?['isMultipart'], isTrue);
      final files = req?['files'] as List?;
      expect(files!.any((f) => f['field'] == 'avatar' && f['filename'] == 'new.png'), isTrue);
    });

    test('update with "fieldName+" appends files in multipart', () async {
      httpAdapter.mockResponse(200, {
        'message': 'Updated',
        'data': {'id': 'rec-1'},
      });

      final upload = FileUpload(bytes: [5], filename: 'extra.jpg', mimeType: 'image/jpeg');

      await sdk.records.update('posts', 'rec-1', {'gallery+': [upload]});

      final req = httpAdapter.lastRequest;
      expect(req?['isMultipart'], isTrue);
      final files = req?['files'] as List?;
      expect(files!.any((f) => f['field'] == 'gallery+'), isTrue);
    });

    test('update with "fieldName-" remove selector sends JSON', () async {
      httpAdapter.mockResponse(200, {
        'message': 'Updated',
        'data': {'id': 'rec-1'},
      });

      await sdk.records.update('posts', 'rec-1', {
        'gallery-': [{'path': 'collections/posts/abc.jpg'}],
      });

      final req = httpAdapter.lastRequest;
      // No FileUploads — must send as plain JSON
      expect(req?['isMultipart'], isNot(isTrue));
    });
  });
}
