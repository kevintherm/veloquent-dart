import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:veloquent_sdk/veloquent_sdk.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesAdapter', () {
    late SharedPreferences preferences;
    late SharedPreferencesAdapter adapter;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'key1': 'value1'});
      preferences = await SharedPreferences.getInstance();
      adapter = SharedPreferencesAdapter(preferences);
    });

    test('isAsync should be false', () {
      expect(adapter.isAsync, isFalse);
    });

    test('getItem returns correct value', () {
      expect(adapter.getItem('key1'), 'value1');
      expect(adapter.getItem('nonexistent'), isNull);
    });

    test('setItem updates value', () {
      adapter.setItem('key2', 'value2');
      expect(preferences.getString('key2'), 'value2');
    });

    test('removeItem removes value', () {
      adapter.removeItem('key1');
      expect(preferences.getString('key1'), isNull);
    });

    test('clear removes all values', () {
      adapter.setItem('key2', 'value2');
      adapter.clear();
      expect(preferences.getString('key1'), isNull);
      expect(preferences.getString('key2'), isNull);
    });

    test('async methods work correctly', () async {
      await adapter.setItemAsync('asyncKey', 'asyncValue');
      expect(await adapter.getItemAsync('asyncKey'), 'asyncValue');
      await adapter.removeItemAsync('asyncKey');
      expect(await adapter.getItemAsync('asyncKey'), isNull);
    });
  });

  group('SecureStorageAdapter', () {
    late MockFlutterSecureStorage mockSecureStorage;
    late SecureStorageAdapter adapter;

    setUp(() {
      mockSecureStorage = MockFlutterSecureStorage();
      adapter = SecureStorageAdapter(mockSecureStorage);
    });

    test('isAsync should be true', () {
      expect(adapter.isAsync, isTrue);
    });

    test('sync methods should throw StateError', () {
      expect(() => adapter.getItem('key'), throwsStateError);
      expect(() => adapter.setItem('key', 'val'), throwsStateError);
      expect(() => adapter.removeItem('key'), throwsStateError);
      expect(() => adapter.clear(), throwsStateError);
    });

    test('getItemAsync calls read', () async {
      when(() => mockSecureStorage.read(key: 'key1'))
          .thenAnswer((_) async => 'value1');

      final result = await adapter.getItemAsync('key1');
      expect(result, 'value1');
      verify(() => mockSecureStorage.read(key: 'key1')).called(1);
    });

    test('setItemAsync calls write', () async {
      when(() => mockSecureStorage.write(key: 'key2', value: 'value2'))
          .thenAnswer((_) async => {});

      await adapter.setItemAsync('key2', 'value2');
      verify(() => mockSecureStorage.write(key: 'key2', value: 'value2'))
          .called(1);
    });

    test('removeItemAsync calls delete', () async {
      when(() => mockSecureStorage.delete(key: 'key1'))
          .thenAnswer((_) async => {});

      await adapter.removeItemAsync('key1');
      verify(() => mockSecureStorage.delete(key: 'key1')).called(1);
    });

    test('clearAsync calls deleteAll', () async {
      when(() => mockSecureStorage.deleteAll()).thenAnswer((_) async => {});

      await adapter.clearAsync();
      verify(() => mockSecureStorage.deleteAll()).called(1);
    });
  });
}
