import 'dart:convert';
import 'package:test/test.dart';
import 'package:veloquent_sdk/veloquent_sdk.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MemoryStorage extends StorageAdapter {
  @override
  bool get isAsync => false;

  final Map<String, String?> data = {};

  @override
  String? getItem(String key) => data[key];

  @override
  void setItem(String key, String value) => data[key] = value;

  @override
  void removeItem(String key) => data.remove(key);

  @override
  void clear() => data.clear();
}

class NetworkFailAdapter extends HttpAdapter {
  @override
  Future<HttpResponse> request(HttpRequest req) async {
    throw const CachingNetworkError();
  }

  @override
  Stream<List<int>> requestStream(HttpRequest req) async* {}
}

class SuccessAdapter extends HttpAdapter {
  SuccessAdapter([this.responseData = const {'data': <String, dynamic>{}}]);

  final Map<String, dynamic> responseData;
  final List<HttpRequest> calls = [];

  @override
  Future<HttpResponse> request(HttpRequest req) async {
    calls.add(req);
    return HttpResponse(
      status: 200,
      statusText: 'OK',
      headers: const {'content-type': 'application/json'},
      data: responseData,
    );
  }

  @override
  Stream<List<int>> requestStream(HttpRequest req) async* {}
}

class MockHttpAdapter extends HttpAdapter {
  final Map<String, HttpResponse> responses = {};
  final List<HttpRequest> calls = [];

  void setResponse(String method, String url, int status, Map<String, dynamic> data) {
    responses['${method.toUpperCase()}:$url'] = HttpResponse(
      status: status,
      statusText: 'OK',
      headers: const {'content-type': 'application/json'},
      data: data,
    );
  }

  @override
  Future<HttpResponse> request(HttpRequest req) async {
    calls.add(req);
    final key = '${req.method.toUpperCase()}:${req.url}';
    if (responses.containsKey(key)) {
      return responses[key]!;
    }
    throw const CachingNetworkError();
  }

  @override
  Stream<List<int>> requestStream(HttpRequest req) async* {}
}

CachingAdapter makeAdapter(
  HttpAdapter inner, {
  MemoryStorage? storage,
}) {
  return CachingAdapter(
    inner,
    storage ?? MemoryStorage(),
    ttl: const Duration(minutes: 5),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CachingAdapter — GET requests', () {
    test('caches successful response to storage', () async {
      final success = SuccessAdapter({
        'items': [
          {'id': '1', 'name': 'A'}
        ]
      });
      final storage = MemoryStorage();
      final adapter = makeAdapter(success, storage: storage);

      const url = 'https://api.example.com/api/collections/posts/records';
      final res = await adapter.request(HttpRequest(method: 'GET', url: url));

      expect(res.status, equals(200));
      expect((res.data as Map)['items'], hasLength(1));

      // Verify written to storage
      final cachedRaw = storage.getItem('vp:cache:$url');
      expect(cachedRaw, isNotNull);
      final cached = jsonDecode(cachedRaw!);
      expect(cached['data']['items'][0]['name'], equals('A'));
      expect(cached['timestamp'], isA<int>());

      // Verify registered in registry
      final registryRaw = storage.getItem('vp:cache_registry');
      expect(registryRaw, isNotNull);
      final registry = jsonDecode(registryRaw!);
      expect(registry, contains('vp:cache:$url'));
    });

    test('falls back to cached data on network error', () async {
      final mock = MockHttpAdapter();
      final storage = MemoryStorage();
      final adapter = makeAdapter(mock, storage: storage);

      const url = 'https://api.example.com/api/collections/posts/records';

      // Seed cache
      storage.setItem(
        'vp:cache:$url',
        jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': {
            'items': [
              {'id': '99', 'name': 'Old'}
            ]
          }
        }),
      );
      storage.setItem('vp:cache_registry', jsonEncode(['vp:cache:$url']));

      // Execute GET — inner throws, falls back
      final res = await adapter.request(HttpRequest(method: 'GET', url: url));
      expect(res.status, equals(200));
      expect(res.statusText, equals('Cached Fallback'));
      expect((res.data as Map)['items'][0]['name'], equals('Old'));
    });

    test('throws if no cache exists and network fails', () async {
      final adapter = makeAdapter(NetworkFailAdapter());
      const url = 'https://api.example.com/api/collections/posts/records';

      expect(
        () => adapter.request(HttpRequest(method: 'GET', url: url)),
        throwsA(isA<CachingNetworkError>()),
      );
    });
  });

  group('CachingAdapter — cache invalidation', () {
    test('successful online write invalidates matching collection cache', () async {
      final mock = MockHttpAdapter();
      final storage = MemoryStorage();
      final adapter = makeAdapter(mock, storage: storage);

      const listUrl = 'https://api.example.com/api/collections/posts/records';
      const detailUrl = 'https://api.example.com/api/collections/posts/records/123';
      const otherUrl = 'https://api.example.com/api/collections/comments/records';

      // Seed caches
      storage.setItem('vp:cache:$listUrl', jsonEncode({'timestamp': 123, 'data': {}}));
      storage.setItem('vp:cache:$detailUrl', jsonEncode({'timestamp': 123, 'data': {}}));
      storage.setItem('vp:cache:$otherUrl', jsonEncode({'timestamp': 123, 'data': {}}));
      storage.setItem(
        'vp:cache_registry',
        jsonEncode([
          'vp:cache:$listUrl',
          'vp:cache:$detailUrl',
          'vp:cache:$otherUrl',
        ]),
      );

      // Perform successful online mutation (POST) on posts collection
      mock.setResponse('POST', listUrl, 201, {'id': '456'});
      await adapter.request(HttpRequest(
        method: 'POST',
        url: listUrl,
        body: {'title': 'New Post'},
      ));

      // Verify posts caches are deleted, but comments cache remains
      expect(storage.getItem('vp:cache:$listUrl'), isNull);
      expect(storage.getItem('vp:cache:$detailUrl'), isNull);
      expect(storage.getItem('vp:cache:$otherUrl'), isNotNull);

      // Verify registry updated
      final registryRaw = storage.getItem('vp:cache_registry');
      expect(registryRaw, isNotNull);
      final registry = jsonDecode(registryRaw!);
      expect(registry, isNot(contains('vp:cache:$listUrl')));
      expect(registry, isNot(contains('vp:cache:$detailUrl')));
      expect(registry, contains('vp:cache:$otherUrl'));
    });
  });

  group('CachingAdapter — optimistic updates', () {
    test('POST 202 appends item to cached list', () async {
      final mock = MockHttpAdapter();
      final storage = MemoryStorage();
      final adapter = makeAdapter(mock, storage: storage);

      const listUrl = 'https://api.example.com/api/collections/posts/records';

      // Seed cached list
      storage.setItem(
        'vp:cache:$listUrl',
        jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': {
            'items': [
              {'id': '1', 'title': 'Post 1'}
            ]
          }
        }),
      );
      storage.setItem('vp:cache_registry', jsonEncode(['vp:cache:$listUrl']));

      // Trigger offline mutation (returned 202)
      mock.setResponse('POST', listUrl, 202, {
        'status': 202,
        'data': {
          'title': 'Post 2',
          '_queued': true,
          '_queue_id': 'q-999',
        }
      });

      await adapter.request(HttpRequest(
        method: 'POST',
        url: listUrl,
        body: {'title': 'Post 2'},
      ));

      // Read updated cache
      final cachedRaw = storage.getItem('vp:cache:$listUrl');
      expect(cachedRaw, isNotNull);
      final cached = jsonDecode(cachedRaw!);
      final items = cached['data']['items'] as List;
      expect(items, hasLength(2));
      expect(items[1]['id'], equals('q-999'));
      expect(items[1]['title'], equals('Post 2'));
      expect(items[1]['_queued'], isTrue);
    });

    test('PATCH 202 updates item in cached list and detail cache', () async {
      final mock = MockHttpAdapter();
      final storage = MemoryStorage();
      final adapter = makeAdapter(mock, storage: storage);

      const listUrl = 'https://api.example.com/api/collections/posts/records';
      const detailUrl = 'https://api.example.com/api/collections/posts/records/123';

      // Seed list and detail caches
      storage.setItem(
        'vp:cache:$listUrl',
        jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': {
            'items': [
              {'id': '123', 'title': 'Original'},
              {'id': '456', 'title': 'Other'}
            ]
          }
        }),
      );
      storage.setItem(
        'vp:cache:$detailUrl',
        jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': {'id': '123', 'title': 'Original'}
        }),
      );
      storage.setItem(
        'vp:cache_registry',
        jsonEncode([
          'vp:cache:$listUrl',
          'vp:cache:$detailUrl',
        ]),
      );

      // Trigger offline update (PATCH 202)
      mock.setResponse('PATCH', detailUrl, 202, {
        'status': 202,
        'data': {'title': 'Updated Title', '_queued': true}
      });

      await adapter.request(HttpRequest(
        method: 'PATCH',
        url: detailUrl,
        body: {'title': 'Updated Title'},
      ));

      // Check list cache updated
      final cachedListRaw = storage.getItem('vp:cache:$listUrl');
      expect(cachedListRaw, isNotNull);
      final cachedList = jsonDecode(cachedListRaw!);
      final items = cachedList['data']['items'] as List;
      expect(items[0]['title'], equals('Updated Title'));
      expect(items[0]['_queued'], isTrue);
      expect(items[1]['title'], equals('Other'));

      // Check detail cache updated
      final cachedDetailRaw = storage.getItem('vp:cache:$detailUrl');
      expect(cachedDetailRaw, isNotNull);
      final cachedDetail = jsonDecode(cachedDetailRaw!);
      expect(cachedDetail['data']['title'], equals('Updated Title'));
      expect(cachedDetail['data']['_queued'], isTrue);
    });

    test('DELETE 202 removes item from cached list and removes detail cache', () async {
      final mock = MockHttpAdapter();
      final storage = MemoryStorage();
      final adapter = makeAdapter(mock, storage: storage);

      const listUrl = 'https://api.example.com/api/collections/posts/records';
      const detailUrl = 'https://api.example.com/api/collections/posts/records/123';

      // Seed list and detail caches
      storage.setItem(
        'vp:cache:$listUrl',
        jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': {
            'items': [
              {'id': '123', 'title': 'A'},
              {'id': '456', 'title': 'B'}
            ]
          }
        }),
      );
      storage.setItem(
        'vp:cache:$detailUrl',
        jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': {'id': '123', 'title': 'A'}
        }),
      );
      storage.setItem(
        'vp:cache_registry',
        jsonEncode([
          'vp:cache:$listUrl',
          'vp:cache:$detailUrl',
        ]),
      );

      // Trigger offline delete (DELETE 202)
      mock.setResponse('DELETE', detailUrl, 202, {
        'status': 202,
        'data': {'_queued': true}
      });

      await adapter.request(HttpRequest(method: 'DELETE', url: detailUrl));

      // Check list cache removes record
      final cachedListRaw = storage.getItem('vp:cache:$listUrl');
      expect(cachedListRaw, isNotNull);
      final cachedList = jsonDecode(cachedListRaw!);
      final items = cachedList['data']['items'] as List;
      expect(items, hasLength(1));
      expect(items[0]['id'], equals('456'));

      // Check detail cache is deleted
      expect(storage.getItem('vp:cache:$detailUrl'), isNull);

      // Registry contains only list cache
      final registryRaw = storage.getItem('vp:cache_registry');
      expect(registryRaw, isNotNull);
      final registry = jsonDecode(registryRaw!);
      expect(registry, contains('vp:cache:$listUrl'));
      expect(registry, isNot(contains('vp:cache:$detailUrl')));
    });
  });
}
