import '../adapters/http/types.dart';
import '../adapters/realtime/types.dart';
import '../adapters/storage/types.dart';

class VeloquentConfig {
  const VeloquentConfig({
    required this.apiUrl,
    required this.http,
    required this.storage,
    this.realtime,
    this.timeout = defaultTimeout,
    this.retryAttempts = defaultRetryAttempts,
  });

  static const Duration defaultTimeout = Duration(milliseconds: 30000);
  static const int defaultRetryAttempts = 1;

  final String apiUrl;
  final HttpAdapter http;
  final StorageAdapter storage;
  final RealtimeAdapter? realtime;
  final Duration timeout;
  final int retryAttempts;

  static VeloquentConfig validate({
    required String apiUrl,
    required HttpAdapter? http,
    required StorageAdapter? storage,
    RealtimeAdapter? realtime,
    Duration? timeout,
    int? retryAttempts,
  }) {
    final normalizedApiUrl = apiUrl.trim();
    if (normalizedApiUrl.isEmpty) {
      throw ArgumentError('SDK: apiUrl is required and must be a non-empty string');
    }
    if (http == null) {
      throw ArgumentError('SDK: http adapter is required');
    }
    if (storage == null) {
      throw ArgumentError('SDK: storage adapter is required');
    }

    return VeloquentConfig(
      apiUrl: normalizedApiUrl.replaceFirst(RegExp(r'/+$'), ''),
      http: http,
      storage: storage,
      realtime: realtime,
      timeout: timeout ?? defaultTimeout,
      retryAttempts: retryAttempts ?? defaultRetryAttempts,
    );
  }
}
