import 'dart:convert';

import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import 'types.dart';

class PusherChannelsAdapter implements RealtimeAdapter {
  PusherChannelsAdapter(
    this._pusher, {
    this.autoConnect = true,
  });

  final PusherChannelsFlutter _pusher;
  final bool autoConnect;

  bool _connected = false;
  final Map<String, _PusherRealtimeChannel> _channels = <String, _PusherRealtimeChannel>{};

  @override
  Future<RealtimeChannel> privateChannel(String channelName) async {
    final normalized = _normalizeChannelName(channelName);
    final existing = _channels[normalized];
    if (existing != null) {
      return existing;
    }

    final wrapper = _PusherRealtimeChannel(normalized);
    await _pusher.subscribe(
      channelName: normalized,
      onEvent: (PusherEvent event) {
        wrapper.dispatch(event.eventName, _normalizePayload(event.data));
      },
    );

    if (autoConnect && !_connected) {
      await _pusher.connect();
      _connected = true;
    }

    _channels[normalized] = wrapper;
    return wrapper;
  }

  @override
  Future<void> leave(String channelName) async {
    final normalized = _normalizeChannelName(channelName);
    await _pusher.unsubscribe(channelName: normalized);
    _channels.remove(normalized);
  }

  @override
  Future<void> disconnect() async {
    _channels.clear();
    _connected = false;
    await _pusher.disconnect();
  }

  String _normalizeChannelName(String channelName) {
    if (channelName.startsWith('private-')) {
      return channelName;
    }
    return 'private-$channelName';
  }

  dynamic _normalizePayload(dynamic payload) {
    if (payload is! String) {
      return payload;
    }

    final trimmed = payload.trim();
    if (trimmed.isEmpty) {
      return payload;
    }

    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return payload;
    }
  }
}

class _PusherRealtimeChannel implements RealtimeChannel {
  _PusherRealtimeChannel(this.channelName);

  final String channelName;
  final Map<String, List<RealtimeChannelEventHandler>> _listeners =
      <String, List<RealtimeChannelEventHandler>>{};

  @override
  void listen(String eventName, RealtimeChannelEventHandler callback) {
    final listeners = _listeners.putIfAbsent(eventName, () => <RealtimeChannelEventHandler>[]);
    listeners.add(callback);
  }

  void dispatch(String eventName, dynamic payload) {
    final plain = eventName.startsWith('.') ? eventName.substring(1) : eventName;
    final dotted = '.$plain';

    final handlers = <RealtimeChannelEventHandler>{
      ...?_listeners[eventName],
      ...?_listeners[plain],
      ...?_listeners[dotted],
    };

    for (final handler in handlers) {
      handler(payload);
    }
  }
}

RealtimeAdapter createPusherChannelsAdapter(
  PusherChannelsFlutter pusher, {
  bool autoConnect = true,
}) {
  return PusherChannelsAdapter(pusher, autoConnect: autoConnect);
}

RealtimeAdapter createEchoAdapter(
  PusherChannelsFlutter pusher, {
  bool autoConnect = true,
}) {
  return createPusherChannelsAdapter(pusher, autoConnect: autoConnect);
}
