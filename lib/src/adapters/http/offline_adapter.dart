import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../../errors/sdk_error.dart';
import '../storage/types.dart';
import 'types.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const String _queueKey = 'vp:offline_queue';
const String _tokenKey = 'vp:token';

// ---------------------------------------------------------------------------
// Callback typedefs
// ---------------------------------------------------------------------------

/// Called when a mutation is queued because of a network failure.
typedef OnQueued = void Function(Map<String, dynamic> entry);

/// Called when a queued entry replays successfully.
typedef OnFlushed =
    void Function(Map<String, dynamic> entry, HttpResponse response);

/// Called when a queued entry fails permanently (non-network error, e.g. 4xx).
typedef OnFlushError = void Function(Map<String, dynamic> entry, Object error);

// ---------------------------------------------------------------------------
// Network error detection
// ---------------------------------------------------------------------------

/// Marker exception that test code can throw to simulate a network failure
/// without relying on string matching.
class OfflineNetworkError implements Exception {
  const OfflineNetworkError([this.message = 'Simulated network error']);
  final String message;
  @override
  String toString() => 'OfflineNetworkError: $message';
}

bool _isNetworkError(Object error) {
  if (error is SdkError) return false;
  if (error is OfflineNetworkError) return true;
  final msg = error.toString().toLowerCase();
  return msg.contains('socketexception') ||
      msg.contains('connection refused') ||
      msg.contains('network is unreachable') ||
      msg.contains('no route to host') ||
      msg.contains('failed to fetch') ||
      msg.contains('network request failed') ||
      msg.contains('networkerror') ||
      msg.contains('handshakeexception') ||
      msg.contains('connection reset') ||
      msg.contains('os error');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _mutations = {'POST', 'PATCH', 'DELETE'};

String _generateId() {
  final random = math.Random();
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.split('').map((c) {
    if (c == 'x') return random.nextInt(16).toRadixString(16);
    if (c == 'y') return (random.nextInt(16) & 0x3 | 0x8).toRadixString(16);
    return c;
  }).join();
}

bool _isJsonSerializable(dynamic value) {
  if (value == null) return true;
  try {
    jsonEncode(value);
    return true;
  } catch (_) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// OfflineAdapter
// ---------------------------------------------------------------------------

/// Wraps any [HttpAdapter] with transparent offline mutation queuing.
///
/// Behaviour:
/// - `GET` requests are **never** queued — they fail immediately when offline.
/// - Requests whose body is not JSON-serializable (e.g. [FileUpload] multipart)
///   are **never** queued — they pass straight through to the inner adapter.
/// - `POST` / `PATCH` / `DELETE` with a JSON-serializable body are queued to
///   persistent storage on a network failure and a synthetic 202 response is
///   returned so the caller can continue normally.
/// - The queue is flushed automatically on a periodic interval (default 30 s).
/// - Call [flush] manually for an immediate retry (e.g. after a connectivity
///   event from `connectivity_plus`).
/// - Call [dispose] to cancel the timer when the SDK is torn down.
///
/// ```dart
/// final storage = SharedPreferencesAdapter(prefs);
/// final sdk = Veloquent(
///   apiUrl: 'https://api.example.com',
///   http: OfflineAdapter(
///     FetchAdapter(),
///     storage,
///     onQueued:     (e)    => debugPrint('Queued: ${e['method']} ${e['url']}'),
///     onFlushed:    (e, _) => debugPrint('Synced: ${e['method']} ${e['url']}'),
///     onFlushError: (e, err) => debugPrint('Dropped: $err'),
///   ),
///   storage: storage,
/// );
/// ```
class OfflineAdapter extends HttpAdapter {
  OfflineAdapter(
    this.inner,
    this.storage, {
    this.maxQueueSize = 200,
    Duration flushInterval = const Duration(seconds: 30),
    this.onQueued,
    this.onFlushed,
    this.onFlushError,
  }) {
    if (flushInterval.inMilliseconds > 0) {
      _timer = Timer.periodic(flushInterval, (_) => flush());
    }
  }

  /// The underlying HTTP adapter that actually sends requests.
  final HttpAdapter inner;

  /// Storage adapter used for queue persistence. Pass the same instance as
  /// [VeloquentConfig.storage].
  final StorageAdapter storage;

  /// Maximum number of entries that can be held in the queue.
  /// When the limit is reached, new mutations throw [SdkError] with code
  /// `QUEUE_FULL` instead of being queued.
  final int maxQueueSize;

  /// Called when a mutation is added to the queue.
  final OnQueued? onQueued;

  /// Called when a queued mutation is successfully replayed.
  final OnFlushed? onFlushed;

  /// Called when a queued mutation fails permanently (e.g. 4xx).
  final OnFlushError? onFlushError;

  Timer? _timer;
  bool _flushing = false;

  // -------------------------------------------------------------------------
  // HttpAdapter interface
  // -------------------------------------------------------------------------

  @override
  Future<HttpResponse> request(HttpRequest req) async {
    final isMutation = _mutations.contains(req.method.toUpperCase());

    // Non-serializable body (FileUpload, etc.) — pass through, never queue
    if (isMutation && !_isJsonSerializable(req.body)) {
      return inner.request(req);
    }

    try {
      final queue = await _loadQueue();
      if (queue.isNotEmpty) {
        await flush();
      }
    } catch (_) {}

    try {
      return await inner.request(req);
    } catch (error) {
      if (isMutation && _isNetworkError(error)) {
        return _enqueue(req);
      }
      rethrow;
    }
  }

  @override
  Stream<List<int>> requestStream(HttpRequest request) {
    return inner.requestStream(request);
  }

  // -------------------------------------------------------------------------
  // Public queue management
  // -------------------------------------------------------------------------

  /// Replay all queued entries in FIFO order through [inner].
  /// Safe to call concurrently; overlapping calls are ignored.
  ///
  /// Returns a record with counts: `flushed`, `failed`, `remaining`.
  Future<({int flushed, int failed, int remaining})> flush() async {
    if (_flushing) return (flushed: 0, failed: 0, remaining: 0);
    _flushing = true;

    int flushed = 0;
    int failed = 0;

    try {
      final queue = await _loadQueue();
      if (queue.isEmpty) return (flushed: 0, failed: 0, remaining: 0);

      final remaining = <Map<String, dynamic>>[];

      for (final entry in queue) {
        try {
          // Re-read the latest token so we don't replay with a stale one
          final headers = await _refreshAuthHeader(
            Map<String, String>.from(
              (entry['headers'] as Map? ?? {}).map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              ),
            ),
          );

          Duration? timeout;
          final rawTimeout = entry['timeout'];
          if (rawTimeout is int) {
            timeout = Duration(milliseconds: rawTimeout);
          }

          final response = await inner.request(
            HttpRequest(
              url: entry['url'] as String,
              method: entry['method'] as String,
              headers: headers,
              body: entry['body'],
              timeout: timeout,
            ),
          );

          onFlushed?.call(entry, response);
          flushed++;
        } catch (error) {
          if (_isNetworkError(error)) {
            // Still offline — keep for next flush
            remaining.add(entry);
          } else {
            // Permanent failure (4xx, auth error, etc.) — discard
            failed++;
            onFlushError?.call(entry, error);
          }
        }
      }

      await _saveQueue(remaining);
      return (flushed: flushed, failed: failed, remaining: remaining.length);
    } finally {
      _flushing = false;
    }
  }

  /// The number of pending entries in the queue.
  Future<int> get queueSize async => (await _loadQueue()).length;

  /// Remove all pending entries from the queue.
  Future<void> clearQueue() => _saveQueue([]);

  /// Whether the periodic flush timer is currently active.
  bool get isTimerActive => _timer != null && (_timer?.isActive ?? false);

  /// Stop the periodic flush timer. Call when the SDK is no longer needed.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  Future<HttpResponse> _enqueue(HttpRequest req) async {
    final queue = await _loadQueue();

    if (queue.length >= maxQueueSize) {
      throw SdkError(
        'QUEUE_FULL',
        'Offline queue is full (max $maxQueueSize entries). Request not queued.',
      );
    }

    final entry = <String, dynamic>{
      'id': _generateId(),
      'method': req.method,
      'url': req.url,
      'headers': req.headers ?? {},
      'body': req.body,
      'timeout': req.timeout?.inMilliseconds,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

    queue.add(entry);
    await _saveQueue(queue);
    onQueued?.call(entry);

    // Echo body back as a synthetic 202 response
    final echoData = <String, dynamic>{};
    if (req.body is Map) {
      echoData.addAll(Map<String, dynamic>.from(req.body as Map));
    }
    echoData['_queued'] = true;
    echoData['_queue_id'] = entry['id'];

    return HttpResponse(
      status: 202,
      statusText: 'Queued',
      headers: const {},
      data: {'data': echoData, 'message': 'Request queued for offline replay'},
    );
  }

  Future<List<Map<String, dynamic>>> _loadQueue() async {
    try {
      final String? raw;
      if (storage.isAsync) {
        raw = await storage.getItemAsync(_queueKey);
      } else {
        raw = storage.getItem(_queueKey);
      }
      if (raw == null || raw.isEmpty) return [];
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        return parsed
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    final raw = jsonEncode(queue);
    if (storage.isAsync) {
      await storage.setItemAsync(_queueKey, raw);
    } else {
      storage.setItem(_queueKey, raw);
    }
  }

  Future<Map<String, String>> _refreshAuthHeader(
    Map<String, String> headers,
  ) async {
    try {
      final String? token;
      if (storage.isAsync) {
        token = await storage.getItemAsync(_tokenKey);
      } else {
        token = storage.getItem(_tokenKey);
      }
      if (token != null && token.isNotEmpty) {
        return {...headers, 'authorization': 'Bearer $token'};
      }
    } catch (_) {}
    return headers;
  }
}
