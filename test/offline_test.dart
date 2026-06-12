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
    throw const OfflineNetworkError();
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

/// Fails first [failCount] calls then succeeds.
class EventuallySuccessAdapter extends HttpAdapter {
  EventuallySuccessAdapter(this.failCount);

  final int failCount;
  int _calls = 0;
  final List<HttpRequest> capturedRequests = [];

  @override
  Future<HttpResponse> request(HttpRequest req) async {
    capturedRequests.add(req);
    _calls++;
    if (_calls <= failCount) throw const OfflineNetworkError();
    return HttpResponse(
      status: 200,
      statusText: 'OK',
      headers: const {'content-type': 'application/json'},
      data: const {'data': <String, dynamic>{}},
    );
  }

  @override
  Stream<List<int>> requestStream(HttpRequest req) async* {}
}

class PermanentErrorAdapter extends HttpAdapter {
  @override
  Future<HttpResponse> request(HttpRequest req) async {
    throw SdkError('VALIDATION_ERROR', 'Bad request', statusCode: 422);
  }

  @override
  Stream<List<int>> requestStream(HttpRequest req) async* {}
}

OfflineAdapter makeAdapter(
  HttpAdapter inner, {
  MemoryStorage? storage,
  int maxQueueSize = 200,
  OnQueued? onQueued,
  OnFlushed? onFlushed,
  OnFlushError? onFlushError,
}) {
  return OfflineAdapter(
    inner,
    storage ?? MemoryStorage(),
    maxQueueSize: maxQueueSize,
    flushInterval: Duration.zero, // disable timer — manual flush only
    onQueued: onQueued,
    onFlushed: onFlushed,
    onFlushError: onFlushError,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Mutation queueing
  // -------------------------------------------------------------------------

  group('OfflineAdapter — queueing mutations', () {
    test('POST queued on network error, returns synthetic 202', () async {
      final adapter = makeAdapter(NetworkFailAdapter());
      final res = await adapter.request(HttpRequest(
        method: 'POST',
        url: 'https://api.example.com/api/collections/posts/records',
        body: {'title': 'Hello'},
      ));

      expect(res.status, equals(202));
      final data = (res.data as Map)['data'] as Map;
      expect(data['_queued'], isTrue);
      expect(data['title'], equals('Hello'));
      expect(data['_queue_id'], isA<String>());
    });

    test('PATCH queued on network error', () async {
      final adapter = makeAdapter(NetworkFailAdapter());
      final res = await adapter.request(HttpRequest(
        method: 'PATCH',
        url: 'https://api.example.com/api/collections/posts/records/1',
        body: {'title': 'Updated'},
      ));
      expect(res.status, equals(202));
      expect((res.data as Map)['data']['_queued'], isTrue);
    });

    test('DELETE queued on network error', () async {
      final adapter = makeAdapter(NetworkFailAdapter());
      final res = await adapter.request(HttpRequest(
        method: 'DELETE',
        url: 'https://api.example.com/api/collections/posts/records/1',
      ));
      expect(res.status, equals(202));
      expect((res.data as Map)['data']['_queued'], isTrue);
    });

    test('queued entry count increases with each mutation', () async {
      final adapter = makeAdapter(NetworkFailAdapter());
      expect(await adapter.queueSize, equals(0));
      await adapter.request(HttpRequest(method: 'POST', url: 'https://api.example.com/1', body: {'a': 1}));
      expect(await adapter.queueSize, equals(1));
      await adapter.request(HttpRequest(method: 'POST', url: 'https://api.example.com/2', body: {'b': 2}));
      expect(await adapter.queueSize, equals(2));
    });
  });

  // -------------------------------------------------------------------------
  // GET requests — never queued
  // -------------------------------------------------------------------------

  group('OfflineAdapter — GET requests', () {
    test('GET throws immediately on network error', () async {
      final adapter = makeAdapter(NetworkFailAdapter());
      expect(
        () => adapter.request(HttpRequest(method: 'GET', url: 'https://api.example.com/api/collections/posts/records')),
        throwsA(isA<OfflineNetworkError>()),
      );
    });

    test('GET does not add to queue', () async {
      final adapter = makeAdapter(NetworkFailAdapter());
      try {
        await adapter.request(HttpRequest(method: 'GET', url: 'https://api.example.com/api/collections/posts/records'));
      } catch (_) {}
      expect(await adapter.queueSize, equals(0));
    });

    test('GET automatically attempts to flush queue first if queue is not empty', () async {
      final storage = MemoryStorage();

      final adapter1 = OfflineAdapter(NetworkFailAdapter(), storage, flushInterval: Duration.zero);
      await adapter1.request(HttpRequest(
        method: 'POST',
        url: 'https://api.example.com/api/collections/posts/records',
        body: const {'title': 'A'},
      ));
      expect(await adapter1.queueSize, equals(1));

      final success = SuccessAdapter(const {
        'data': <String, dynamic>{}
      });
      final adapter2 = OfflineAdapter(success, storage, flushInterval: Duration.zero);

      final res = await adapter2.request(HttpRequest(
        method: 'GET',
        url: 'https://api.example.com/api/collections/posts/records',
      ));

      expect(res.status, equals(200));
      expect(await adapter2.queueSize, equals(0));
      expect(success.calls, hasLength(2));
      expect(success.calls[0].method, equals('POST'));
      expect(success.calls[1].method, equals('GET'));
    });
  });

  // -------------------------------------------------------------------------
  // Non-serializable body passthrough
  // -------------------------------------------------------------------------

  group('OfflineAdapter — non-serializable body', () {
    test('non-serializable body passes through (not queued)', () async {
      final success = SuccessAdapter();
      final adapter = makeAdapter(success);
      // A Dart object that is not JSON-encodable (circular via custom class)
      final unserializable = _NonSerializable();
      // Should pass through to the inner adapter (which succeeds)
      final res = await adapter.request(HttpRequest(
        method: 'POST',
        url: 'https://api.example.com/api/collections/posts/records',
        body: unserializable,
      ));
      expect(res.status, equals(200));
      expect(success.calls, hasLength(1));
      expect(await adapter.queueSize, equals(0));
    });
  });

  // -------------------------------------------------------------------------
  // Flush — success
  // -------------------------------------------------------------------------

  group('OfflineAdapter — flush success', () {
    test('flush replays queued entries and clears queue', () async {
      final storage = MemoryStorage();
      final adapter = OfflineAdapter(
        NetworkFailAdapter(),
        storage,
        flushInterval: Duration.zero,
      );

      await adapter.request(HttpRequest(method: 'POST', url: 'https://api.example.com/1', body: {'title': 'A'}));
      expect(await adapter.queueSize, equals(1));

      // Replace inner with success adapter
      final successAdapter = OfflineAdapter(
        SuccessAdapter(),
        storage,
        flushInterval: Duration.zero,
      );
      final result = await successAdapter.flush();
      expect(result.flushed, equals(1));
      expect(result.remaining, equals(0));
      expect(await successAdapter.queueSize, equals(0));
    });

    test('flush replays entries in FIFO order', () async {
      final storage = MemoryStorage();
      final netFail = OfflineAdapter(NetworkFailAdapter(), storage, flushInterval: Duration.zero);
      await netFail.request(HttpRequest(method: 'POST', url: 'https://api.example.com/1', body: {'order': 1}));
      await netFail.request(HttpRequest(method: 'POST', url: 'https://api.example.com/2', body: {'order': 2}));

      final success = SuccessAdapter();
      final flusher = OfflineAdapter(success, storage, flushInterval: Duration.zero);
      await flusher.flush();

      expect(success.calls[0].url, equals('https://api.example.com/1'));
      expect(success.calls[1].url, equals('https://api.example.com/2'));
    });

    test('flush returns correct counts', () async {
      final storage = MemoryStorage();
      final netFail = OfflineAdapter(NetworkFailAdapter(), storage, flushInterval: Duration.zero);
      await netFail.request(HttpRequest(method: 'POST', url: 'https://api.example.com/1', body: {}));
      await netFail.request(HttpRequest(method: 'PATCH', url: 'https://api.example.com/2', body: {}));

      final flusher = OfflineAdapter(SuccessAdapter(), storage, flushInterval: Duration.zero);
      final result = await flusher.flush();
      expect(result.flushed, equals(2));
      expect(result.failed, equals(0));
      expect(result.remaining, equals(0));
    });
  });

  // -------------------------------------------------------------------------
  // Flush — permanent 4xx failure
  // -------------------------------------------------------------------------

  group('OfflineAdapter — flush 4xx discard', () {
    test('4xx discards the entry and fires onFlushError', () async {
      final storage = MemoryStorage();
      Map<String, dynamic>? errorEntry;

      final queuer = OfflineAdapter(NetworkFailAdapter(), storage, flushInterval: Duration.zero);
      await queuer.request(HttpRequest(method: 'POST', url: 'https://api.example.com/1', body: {'bad': true}));

      final flusher = OfflineAdapter(
        PermanentErrorAdapter(),
        storage,
        flushInterval: Duration.zero,
        onFlushError: (entry, _) => errorEntry = entry,
      );
      final result = await flusher.flush();

      expect(result.flushed, equals(0));
      expect(result.failed, equals(1));
      expect(result.remaining, equals(0));
      expect(await flusher.queueSize, equals(0));
      expect(errorEntry, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Flush — still offline
  // -------------------------------------------------------------------------

  group('OfflineAdapter — flush while still offline', () {
    test('network error during flush keeps entry in queue', () async {
      final storage = MemoryStorage();
      final adapter = OfflineAdapter(NetworkFailAdapter(), storage, flushInterval: Duration.zero);
      await adapter.request(HttpRequest(method: 'POST', url: 'https://api.example.com/1', body: {}));

      final result = await adapter.flush();
      expect(result.remaining, equals(1));
      expect(await adapter.queueSize, equals(1));
    });

    test('concurrent flush calls are deduplicated', () async {
      final adapter = makeAdapter(NetworkFailAdapter());
      final results = await Future.wait([adapter.flush(), adapter.flush()]);
      // At most one real flush runs; combined total flushed is 0
      expect(results[0].flushed + results[1].flushed, equals(0));
    });
  });

  // -------------------------------------------------------------------------
  // Queue size limit
  // -------------------------------------------------------------------------

  group('OfflineAdapter — queue size limit', () {
    test('exceeding maxQueueSize throws QUEUE_FULL', () async {
      final adapter = makeAdapter(NetworkFailAdapter(), maxQueueSize: 2);
      await adapter.request(HttpRequest(method: 'POST', url: 'https://api.example.com/1', body: {}));
      await adapter.request(HttpRequest(method: 'POST', url: 'https://api.example.com/2', body: {}));

      expect(
        () => adapter.request(HttpRequest(method: 'POST', url: 'https://api.example.com/3', body: {})),
        throwsA(isA<SdkError>().having((e) => e.code, 'code', 'QUEUE_FULL')),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Callbacks
  // -------------------------------------------------------------------------

  group('OfflineAdapter — callbacks', () {
    test('onQueued fires with correct entry data', () async {
      Map<String, dynamic>? queuedEntry;
      final adapter = makeAdapter(
        NetworkFailAdapter(),
        onQueued: (e) => queuedEntry = e,
      );
      await adapter.request(HttpRequest(method: 'POST', url: 'https://api.example.com/1', body: {'title': 'A'}));
      expect(queuedEntry, isNotNull);
      expect(queuedEntry!['method'], equals('POST'));
      expect((queuedEntry!['body'] as Map)['title'], equals('A'));
      expect(queuedEntry!['id'], isA<String>());
      expect(queuedEntry!['createdAt'], isA<String>());
    });

    test('onFlushed fires on successful replay', () async {
      final storage = MemoryStorage();
      Map<String, dynamic>? flushedEntry;

      final queuer = OfflineAdapter(NetworkFailAdapter(), storage, flushInterval: Duration.zero);
      await queuer.request(HttpRequest(method: 'POST', url: 'https://api.example.com/1', body: {}));

      final flusher = OfflineAdapter(
        SuccessAdapter(),
        storage,
        flushInterval: Duration.zero,
        onFlushed: (e, _) => flushedEntry = e,
      );
      await flusher.flush();
      expect(flushedEntry, isNotNull);
      expect(flushedEntry!['method'], equals('POST'));
    });

    test('onFlushError fires on permanent failure', () async {
      final storage = MemoryStorage();
      Object? capturedError;

      final queuer = OfflineAdapter(NetworkFailAdapter(), storage, flushInterval: Duration.zero);
      await queuer.request(HttpRequest(method: 'POST', url: 'https://api.example.com/1', body: {}));

      final flusher = OfflineAdapter(
        PermanentErrorAdapter(),
        storage,
        flushInterval: Duration.zero,
        onFlushError: (_, err) => capturedError = err,
      );
      await flusher.flush();
      expect(capturedError, isA<SdkError>());
    });
  });

  // -------------------------------------------------------------------------
  // Persistence across instances
  // -------------------------------------------------------------------------

  group('OfflineAdapter — persistence', () {
    test('queue survives re-instantiation with the same storage', () async {
      final storage = MemoryStorage();

      final adapter1 = OfflineAdapter(NetworkFailAdapter(), storage, flushInterval: Duration.zero);
      await adapter1.request(HttpRequest(method: 'POST', url: 'https://api.example.com/1', body: {'title': 'Persisted'}));
      adapter1.dispose();

      final adapter2 = OfflineAdapter(SuccessAdapter(), storage, flushInterval: Duration.zero);
      expect(await adapter2.queueSize, equals(1));
      await adapter2.flush();
      expect(await adapter2.queueSize, equals(0));
      adapter2.dispose();
    });

    test('auth token is refreshed from storage on flush', () async {
      final storage = MemoryStorage();
      storage.setItem('vp:token', 'new-token-xyz');

      final queuer = OfflineAdapter(NetworkFailAdapter(), storage, flushInterval: Duration.zero);
      await queuer.request(HttpRequest(
        method: 'POST',
        url: 'https://api.example.com/1',
        headers: {'authorization': 'Bearer old-token'},
        body: {'title': 'A'},
      ));

      final success = SuccessAdapter();
      final flusher = OfflineAdapter(success, storage, flushInterval: Duration.zero);
      await flusher.flush();

      expect(success.calls.first.headers?['authorization'], equals('Bearer new-token-xyz'));
    });
  });

  // -------------------------------------------------------------------------
  // Housekeeping
  // -------------------------------------------------------------------------

  group('OfflineAdapter — housekeeping', () {
    test('clearQueue removes all pending entries', () async {
      final adapter = makeAdapter(NetworkFailAdapter());
      await adapter.request(HttpRequest(method: 'POST', url: 'https://api.example.com/1', body: {}));
      await adapter.request(HttpRequest(method: 'POST', url: 'https://api.example.com/2', body: {}));
      expect(await adapter.queueSize, equals(2));
      await adapter.clearQueue();
      expect(await adapter.queueSize, equals(0));
    });

    test('dispose cancels the timer', () {
      final storage = MemoryStorage();
      final adapter = OfflineAdapter(
        NetworkFailAdapter(),
        storage,
        flushInterval: const Duration(seconds: 60),
      );
      expect(adapter.isTimerActive, isTrue);
      adapter.dispose();
      expect(adapter.isTimerActive, isFalse);
    });

    test('empty flush returns zero counts', () async {
      final adapter = makeAdapter(SuccessAdapter());
      final result = await adapter.flush();
      expect(result.flushed, equals(0));
      expect(result.failed, equals(0));
      expect(result.remaining, equals(0));
    });
  });
}

/// A non-JSON-serializable value used to test the passthrough path.
class _NonSerializable {
  // jsonEncode will throw on this because it has no toJson() method.
}
