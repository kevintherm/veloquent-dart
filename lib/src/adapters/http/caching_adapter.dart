import 'dart:async';
import 'dart:convert';
import '../../errors/sdk_error.dart';
import '../storage/types.dart';
import 'types.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const String _registryKey = 'vp:cache_registry';

// ---------------------------------------------------------------------------
// Network error detection
// ---------------------------------------------------------------------------

/// Marker exception that test code can throw to simulate a network failure.
class CachingNetworkError implements Exception {
  const CachingNetworkError([this.message = 'Simulated network error']);
  final String message;
  @override
  String toString() => 'CachingNetworkError: $message';
}

bool _isNetworkError(Object error) {
  if (error is SdkError) return false;
  if (error is CachingNetworkError) return true;
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
// CachingAdapter
// ---------------------------------------------------------------------------

/// Wraps any [HttpAdapter] to cache GET responses, fallback during network outages,
/// perform optimistic updates on offline writes, and invalidate caches on successful online writes.
class CachingAdapter extends HttpAdapter {
  CachingAdapter(
    this.inner,
    this.storage, {
    this.ttl = const Duration(minutes: 5),
  });

  /// The underlying HTTP adapter.
  final HttpAdapter inner;

  /// The storage adapter to persist cached data.
  final StorageAdapter storage;

  /// Time to live for cache entries.
  final Duration ttl;

  // -------------------------------------------------------------------------
  // HttpAdapter interface
  // -------------------------------------------------------------------------

  @override
  Future<HttpResponse> request(HttpRequest req) async {
    final method = req.method.toUpperCase();

    // 1. GET requests: read through cache or fall back
    if (method == 'GET') {
      final cacheKey = 'vp:cache:${req.url}';
      try {
        final response = await inner.request(req);
        await _saveToCache(cacheKey, response.data);
        return response;
      } catch (error) {
        if (_isNetworkError(error)) {
          final cached = await _readFromCache(cacheKey);
          if (cached != null) {
            return HttpResponse(
              status: 200,
              statusText: 'Cached Fallback',
              headers: const {},
              data: cached['data'],
            );
          }
        }
        rethrow;
      }
    }

    // 2. Mutations (POST, PATCH, DELETE)
    final response = await inner.request(req);

    if (response.status == 202) {
      // Offline synthetic queued response — apply optimistic update to GET cache
      await _applyOptimisticUpdate(req, response.data);
    } else if (response.status >= 200 && response.status < 300) {
      // Online success — invalidate cache for this collection
      await _invalidateCollectionCache(req.url);
    }

    return response;
  }

  @override
  Stream<List<int>> requestStream(HttpRequest req) {
    return inner.requestStream(req);
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Future<void> _saveToCache(String key, dynamic data) async {
    final entry = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    };
    final raw = jsonEncode(entry);

    if (storage.isAsync) {
      await storage.setItemAsync(key, raw);
    } else {
      storage.setItem(key, raw);
    }

    await _addToRegistry(key);
  }

  Future<Map<String, dynamic>?> _readFromCache(String key) async {
    try {
      final String? raw;
      if (storage.isAsync) {
        raw = await storage.getItemAsync(key);
      } else {
        raw = storage.getItem(key);
      }
      if (raw == null || raw.isEmpty) return null;

      final parsed = jsonDecode(raw);
      if (parsed is Map && parsed.containsKey('timestamp')) {
        return Map<String, dynamic>.from(parsed);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _addToRegistry(String key) async {
    try {
      final registry = await _loadRegistry();
      if (!registry.contains(key)) {
        registry.add(key);
        await _saveRegistry(registry);
      }
    } catch (_) {}
  }

  Future<List<String>> _loadRegistry() async {
    try {
      final String? raw;
      if (storage.isAsync) {
        raw = await storage.getItemAsync(_registryKey);
      } else {
        raw = storage.getItem(_registryKey);
      }
      if (raw == null || raw.isEmpty) return [];
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        return parsed.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveRegistry(List<String> registry) async {
    final raw = jsonEncode(registry);
    if (storage.isAsync) {
      await storage.setItemAsync(_registryKey, raw);
    } else {
      storage.setItem(_registryKey, raw);
    }
  }

  Future<void> _invalidateCollectionCache(String url) async {
    try {
      final collection = _extractCollectionName(url);
      if (collection == null) return;

      final registry = await _loadRegistry();
      final remaining = <String>[];
      final pattern = '/collections/$collection/records';

      for (final key in registry) {
        if (key.contains(pattern)) {
          if (storage.isAsync) {
            await storage.removeItemAsync(key);
          } else {
            storage.removeItem(key);
          }
        } else {
          remaining.add(key);
        }
      }

      await _saveRegistry(remaining);
    } catch (_) {}
  }

  String? _extractCollectionName(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final idx = segments.indexOf('collections');
      if (idx != -1 && idx + 1 < segments.length) {
        return segments[idx + 1];
      }
    } catch (_) {}
    return null;
  }

  Future<void> _applyOptimisticUpdate(HttpRequest req, dynamic responseData) async {
    try {
      final collection = _extractCollectionName(req.url);
      if (collection == null) return;

      final registry = await _loadRegistry();
      final pattern = '/collections/$collection/records';

      final method = req.method.toUpperCase();
      final reqBody = req.body is Map ? Map<String, dynamic>.from(req.body as Map) : null;
      if (reqBody == null && method != 'DELETE') return;

      String? queueId;
      if (responseData is Map && responseData.containsKey('data')) {
        final data = responseData['data'];
        if (data is Map && data.containsKey('_queue_id')) {
          queueId = data['_queue_id']?.toString();
        }
      }

      // Find recordId in url
      final uri = Uri.parse(req.url);
      final segments = uri.pathSegments;
      final recordIdx = segments.indexOf('records');
      final recordId = (recordIdx != -1 && recordIdx + 1 < segments.length) ? segments[recordIdx + 1] : null;

      for (final key in registry) {
        if (key.contains(pattern)) {
          final cached = await _readFromCache(key);
          if (cached == null || cached['data'] == null) continue;

          var cacheUpdated = false;
          var cacheData = cached['data'];

          // 1. Updating a List Cache (e.g. GET /api/collections/{collection}/records)
          if (cacheData is Map && cacheData.containsKey('items') && cacheData['items'] is List) {
            var items = List<Map<String, dynamic>>.from(
              (cacheData['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
            );

            if (method == 'POST' && queueId != null) {
              final newRecord = {
                ...reqBody!,
                'id': queueId,
                '_queued': true,
              };
              items.add(newRecord);
              cacheUpdated = true;
            } else if (method == 'PATCH' && recordId != null) {
              items = items.map((item) {
                if (item['id'] == recordId) {
                  return {...item, ...reqBody!, '_queued': true};
                }
                return item;
              }).toList();
              cacheUpdated = true;
            } else if (method == 'DELETE' && recordId != null) {
              items.removeWhere((item) => item['id'] == recordId);
              cacheUpdated = true;
            }

            if (cacheUpdated) {
              cacheData = Map<String, dynamic>.from(cacheData);
              cacheData['items'] = items;
            }
          }
          // 2. Updating a Detail Cache (e.g. GET /api/collections/{collection}/records/{id})
          else if (cacheData is Map && cacheData['id'] == recordId) {
            if (method == 'PATCH') {
              cacheData = {
                ...Map<String, dynamic>.from(cacheData),
                ...reqBody!,
                '_queued': true,
              };
              cacheUpdated = true;
            } else if (method == 'DELETE') {
              if (storage.isAsync) {
                await storage.removeItemAsync(key);
              } else {
                storage.removeItem(key);
              }
              final updatedRegistry = (await _loadRegistry()).where((k) => k != key).toList();
              await _saveRegistry(updatedRegistry);
              continue;
            }
          }

          if (cacheUpdated) {
            await _saveToCache(key, cacheData);
          }
        }
      }
    } catch (_) {}
  }
}
