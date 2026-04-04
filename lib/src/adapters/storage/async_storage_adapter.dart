import 'types.dart';

abstract class AsyncStorageBackend {
  Future<String?> getItem(String key);

  Future<void> setItem(String key, String value);

  Future<void> removeItem(String key);

  Future<void> clear();
}

class AsyncStorageAdapter implements StorageAdapter {
  AsyncStorageAdapter(this._storage);

  final AsyncStorageBackend _storage;

  @override
  bool get isAsync => true;

  @override
  String? getItem(String key) {
    throw StateError('Veloquent SDK: Use getItemAsync for this adapter');
  }

  @override
  void setItem(String key, String value) {
    throw StateError('Veloquent SDK: Use setItemAsync for this adapter');
  }

  @override
  void removeItem(String key) {
    throw StateError('Veloquent SDK: Use removeItemAsync for this adapter');
  }

  @override
  void clear() {
    throw StateError('Veloquent SDK: Use clearAsync for this adapter');
  }

  @override
  Future<String?> getItemAsync(String key) async {
    return _storage.getItem(key);
  }

  @override
  Future<void> setItemAsync(String key, String value) async {
    await _storage.setItem(key, value);
  }

  @override
  Future<void> removeItemAsync(String key) async {
    await _storage.removeItem(key);
  }

  @override
  Future<void> clearAsync() async {
    await _storage.clear();
  }
}

AsyncStorageAdapter createAsyncStorageAdapter(AsyncStorageBackend storage) {
  return AsyncStorageAdapter(storage);
}
