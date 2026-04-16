import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:veloquent_sdk/veloquent_sdk.dart';

/// Test double for [FetchAdapter] that records all requests without making
/// real network calls. Supports both JSON and multipart requests.
///
/// Extends [FetchAdapter] so that [FetchAdapter.request] handles the routing
/// (detecting [FileUpload] values and choosing JSON vs multipart). Only the
/// two leaf dispatch methods are overridden here to capture calls without I/O.
class MockHttpAdapter extends FetchAdapter {
  MockHttpAdapter() : super();

  final List<Map<String, dynamic>> requests = [];
  final List<HttpResponse> _responses = [];

  void mockResponse(int status, Map<String, dynamic> data) {
    _responses.add(HttpResponse(
      status: status,
      statusText: status == 200 ? 'OK' : 'Error',
      headers: {'content-type': 'application/json'},
      data: data,
    ));
  }

  HttpResponse _nextResponse() {
    if (_responses.isNotEmpty) return _responses.removeAt(0);
    return HttpResponse(
      status: 200,
      statusText: 'OK',
      headers: {'content-type': 'application/json'},
      data: {'message': 'OK', 'data': {}},
    );
  }

  /// Intercepts normal (JSON) requests — called by [FetchAdapter.request]
  /// after detecting no [FileUpload] values in the body.
  @override
  Future<HttpResponse> sendJsonRequest({
    required String method,
    required Uri uri,
    required Object? encodedBody,
    required Map<String, String> headers,
    required Duration timeout,
    dynamic originalBody,
  }) async {
    requests.add({
      'method': method,
      'url': uri.toString(),
      'headers': headers,
      'body': originalBody is String ? json.decode(originalBody) : originalBody,
      'isMultipart': false,
    });

    return _nextResponse();
  }

  /// Intercepts multipart requests — records metadata without network I/O.
  @override
  Future<HttpResponse> sendMultipartRequest({
    required String method,
    required Uri uri,
    required http.MultipartRequest multipartRequest,
    required Map<String, String> fields,
    required List<Map<String, dynamic>> files,
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    requests.add({
      'method': method,
      'url': uri.toString(),
      'headers': headers,
      'isMultipart': true,
      'fields': fields,
      'files': files,
    });

    return _nextResponse();
  }

  Map<String, dynamic>? get lastRequest => requests.isNotEmpty ? requests.last : null;
}

class MockStorageAdapter extends StorageAdapter {
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

  @override
  Future<void> clearAsync() async => clear();

  @override
  Future<String?> getItemAsync(String key) async => getItem(key);

  @override
  Future<void> removeItemAsync(String key) async => removeItem(key);

  @override
  Future<void> setItemAsync(String key, String value) async => setItem(key, value);
}

class MockAsyncStorageBackend implements AsyncStorageBackend {
  final Map<String, String?> data = {};

  @override
  Future<void> clear() async => data.clear();

  @override
  Future<String?> getItem(String key) async => data[key];

  @override
  Future<void> removeItem(String key) async => data.remove(key);

  @override
  Future<void> setItem(String key, String value) async => data[key] = value;
}

class MockAsyncStorageAdapter extends AsyncStorageAdapter {
  @override
  bool get isAsync => true;

  MockAsyncStorageAdapter() : super(MockAsyncStorageBackend());
}

class MockRealtimeChannel implements RealtimeChannel {
  final Map<String, List<Function(dynamic)>> eventListeners = {};

  @override
  void listen(String eventName, RealtimeChannelEventHandler callback) {
    print('DEBUG: MockRealtimeChannel listening to $eventName');
    eventListeners.putIfAbsent(eventName, () => []).add(callback);
  }

  @override
  Future<void> subscribe(
      Function(String event, dynamic payload) callback) async {}

  @override
  Future<void> unsubscribe() async {}

  @override
  Future<void> trigger(String event, dynamic data) async {}

  void triggerInternal(String event, dynamic payload) {
    final listeners = eventListeners[event];
    if (listeners != null) {
      for (final l in listeners) {
        l(payload);
      }
    }
  }
}

class MockRealtimeAdapter implements RealtimeAdapter {
  final List<String> subscribedChannels = [];
  final List<String> unsubscribedChannels = [];
  final Map<String, MockRealtimeChannel> channels = {};
  String? lastChannelName;

  @override
  Future<void> subscribe(
    String channel,
    Function(String event, dynamic payload) callback,
  ) async {
    subscribedChannels.add(channel);
  }

  @override
  Future<void> unsubscribe(String channel) async {
    unsubscribedChannels.add(channel);
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> leave(String channelName) async {
    unsubscribedChannels.add(channelName);
  }

  @override
  Future<RealtimeChannel> privateChannel(String channelName) async {
    lastChannelName = channelName;
    subscribedChannels.add(channelName);
    final chan = MockRealtimeChannel();
    channels[channelName] = chan;
    return chan;
  }

  void emit(String fullEvent, dynamic payload) {
    // The format is "channelName.record.created"
    final allParts = fullEvent.split('.');
    if (allParts.length < 3) return;
    
    // The last two are "record" and "created/updated/deleted"
    final eventName = allParts.sublist(allParts.length - 2).join('.');
    final channelName = allParts.sublist(0, allParts.length - 2).join('.');
    
    final chan = channels[channelName];
    if (chan != null) {
      chan.triggerInternal('.$eventName', payload);
    }
  }
}
