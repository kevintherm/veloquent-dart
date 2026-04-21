import 'package:shared_preferences/shared_preferences.dart';

import 'types.dart';

class SharedPreferencesAdapter implements StorageAdapter {
  SharedPreferencesAdapter(this._preferences);

  final SharedPreferences _preferences;

  @override
  bool get isAsync => false;

  @override
  String? getItem(String key) {
    return _preferences.getString(key);
  }

  @override
  void setItem(String key, String value) {
    _preferences.setString(key, value);
  }

  @override
  void removeItem(String key) {
    _preferences.remove(key);
  }

  @override
  void clear() {
    _preferences.clear();
  }

  @override
  Future<void> clearAsync() async => clear();

  @override
  Future<String?> getItemAsync(String key) async => getItem(key);

  @override
  Future<void> removeItemAsync(String key) async => removeItem(key);

  @override
  Future<void> setItemAsync(String key, String value) async => setItem(key, value);
}

Future<SharedPreferencesAdapter> createSharedPreferencesAdapter({
  SharedPreferences? preferences,
}) async {
  final resolvedPreferences =
      preferences ?? await SharedPreferences.getInstance();
  return SharedPreferencesAdapter(resolvedPreferences);
}

