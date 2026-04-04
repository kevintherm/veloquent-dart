abstract class StorageAdapter {
  bool get isAsync;

  String? getItem(String key);

  void setItem(String key, String value);

  void removeItem(String key);

  void clear();

  Future<String?> getItemAsync(String key) async {
    return getItem(key);
  }

  Future<void> setItemAsync(String key, String value) async {
    setItem(key, value);
  }

  Future<void> removeItemAsync(String key) async {
    removeItem(key);
  }

  Future<void> clearAsync() async {
    clear();
  }
}
