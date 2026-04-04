typedef RealtimeChannelEventHandler = void Function(dynamic payload);

typedef RealtimeCallback = void Function(String event, dynamic payload);

abstract class RealtimeChannel {
  void listen(String eventName, RealtimeChannelEventHandler callback);
}

abstract class RealtimeAdapter {
  Future<RealtimeChannel> privateChannel(String channelName);

  Future<void> leave(String channelName);

  Future<void> disconnect();
}
