import 'dart:async';

import '../adapters/realtime/types.dart';
import '../core/request.dart';

class _ChannelListener {
  _ChannelListener(this.collection, this.callback);

  final String collection;
  final RealtimeCallback callback;
}

class _ActiveChannel {
  _ActiveChannel({
    required this.adapterChannel,
    required this.heartbeatTimer,
  });

  final RealtimeChannel adapterChannel;
  final Timer heartbeatTimer;
  final Set<_ChannelListener> listeners = <_ChannelListener>{};
}

class Realtime {
  Realtime(this.requestHelper, this._adapter);

  final RequestHelper requestHelper;
  RealtimeAdapter? _adapter;

  RealtimeAdapter? get adapter => _adapter;
  set adapter(RealtimeAdapter? value) => _adapter = value;

  Duration heartbeatInterval = const Duration(seconds: 30);
  final Map<String, _ActiveChannel> _activeChannels = <String, _ActiveChannel>{};
  final Map<String, String> _collectionToChannel = <String, String>{};

  Future<void> disconnect() async {
    for (final sub in _activeChannels.values) {
      sub.heartbeatTimer.cancel();
    }

    final channelNames = _activeChannels.keys.toList();
    for (final name in channelNames) {
      await adapter?.leave(name);
    }

    _activeChannels.clear();
    _collectionToChannel.clear();
    await adapter?.disconnect();
  }

  Future<String> subscribe(String collection,
      {String? filter, String? channel, RealtimeCallback? callback}) async {
    final effectiveAdapter = adapter;
    if (effectiveAdapter == null) {
      throw StateError(
          'SDK: Realtime adapter is not configured. Pass it in Veloquent config.');
    }

    final response = await requestHelper.execute(
      method: 'POST',
      path: '/collections/$collection/subscribe',
      body: {'filter': filter},
    );

    final String? rawChannelName =
        channel ?? (response.data is Map ? response.data['channel'] : null);
    if (rawChannelName == null) {
      throw ArgumentError(
          'SDK: Channel name is required (pass it in options or ensure server returns it).');
    }

    final channelName = rawChannelName.startsWith('private-')
        ? rawChannelName.substring(8)
        : rawChannelName;

    var channelInfo = _activeChannels[channelName];

    if (channelInfo == null) {
      final adapterChannel = await effectiveAdapter.privateChannel(channelName);

      final timer = Timer.periodic(heartbeatInterval, (_) async {
        try {
          await requestHelper.execute(
            method: 'POST',
            path: '/collections/$collection/subscribe',
            body: {'filter': filter},
          );
        } catch (_) {}
      });

      channelInfo = _ActiveChannel(
        adapterChannel: adapterChannel,
        heartbeatTimer: timer,
      );

      _activeChannels[channelName] = channelInfo;

      for (final eventName in ['created', 'updated', 'deleted']) {
        final fullEventName = 'record.$eventName';

        adapterChannel.listen('.$fullEventName', (dynamic payload) {
          final dataToReturn = (payload is Map && payload.containsKey('record'))
              ? payload['record']
              : payload;

          final collectionNameFromPayload = (dataToReturn is Map)
              ? (dataToReturn['_collection'] ?? payload['_collection'])
              : null;

          final handlers = channelInfo!.listeners.toList();
          for (final listener in handlers) {
            if (collectionNameFromPayload != null &&
                collectionNameFromPayload != listener.collection) {
              continue;
            }
            listener.callback(fullEventName, dataToReturn);
          }
        });
      }
    }

    if (callback != null) {
      channelInfo.listeners.add(_ChannelListener(collection, callback));
    }
    _collectionToChannel[collection] = channelName;

    return channelName;
  }

  Future<void> unsubscribe(String collection) async {
    final channelName = _collectionToChannel[collection];
    if (channelName == null) return;

    try {
      await requestHelper.execute(
        method: 'DELETE',
        path: '/collections/$collection/subscribe',
      );
    } catch (_) {}

    final channelInfo = _activeChannels[channelName];
    if (channelInfo != null) {
      channelInfo.listeners.removeWhere((l) => l.collection == collection);

      if (channelInfo.listeners.isEmpty) {
        channelInfo.heartbeatTimer.cancel();
        await adapter?.leave(channelName);
        _activeChannels.remove(channelName);
      }
    }
    _collectionToChannel.remove(collection);
  }
}
