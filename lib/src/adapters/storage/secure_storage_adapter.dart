import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'types.dart';

class SecureStorageAdapter implements StorageAdapter {
  SecureStorageAdapter([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  bool get isAsync => true;

  @override
  String? getItem(String key) {
    throw StateError('SecureStorageAdapter: Use getItemAsync for this adapter');
  }

  @override
  void setItem(String key, String value) {
    throw StateError('SecureStorageAdapter: Use setItemAsync for this adapter');
  }

  @override
  void removeItem(String key) {
    throw StateError('SecureStorageAdapter: Use removeItemAsync for this adapter');
  }

  @override
  void clear() {
    throw StateError('SecureStorageAdapter: Use clearAsync for this adapter');
  }

  @override
  Future<String?> getItemAsync(String key) async {
    return _storage.read(key: key);
  }

  @override
  Future<void> setItemAsync(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> removeItemAsync(String key) async {
    await _storage.delete(key: key);
  }

  @override
  Future<void> clearAsync() async {
    await _storage.deleteAll();
  }
}

SecureStorageAdapter createSecureStorageAdapter([FlutterSecureStorage? storage]) {
  return SecureStorageAdapter(storage);
}
