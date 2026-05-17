import 'package:test/test.dart';
import 'package:veloquent_sdk/veloquent_sdk.dart';
import 'mocks.dart';

void main() {
  group('SdkError', () {
    test('resilient getFieldErrors supports both nested and flat errors structures', () {
      // Flat details structure
      final error1 = SdkError('VALIDATION_FAILED', 'Validation failed',
          statusCode: 422,
          details: {
            'email': ['The email has already been taken.'],
            'password': ['Too short']
          });
      expect(error1.getFieldErrors('email'), equals(['The email has already been taken.']));
      expect(error1.getFirstFieldError('password'), equals('Too short'));

      // Nested errors structure (e.g. when details is the full API payload containing `errors`)
      final error2 = SdkError('VALIDATION_FAILED', 'Validation failed',
          statusCode: 422,
          details: {
            'code': 'VALIDATION_FAILED',
            'message': 'Validation failed',
            'errors': {
              'email': ['The email has already been taken.'],
              'password': ['Too short']
            }
          });
      expect(error2.getFieldErrors('email'), equals(['The email has already been taken.']));
      expect(error2.getFirstFieldError('password'), equals('Too short'));
    });

    test('extracts custom server error code and error_type', () async {
      final httpAdapter = MockHttpAdapter();
      final sdk = Veloquent(
        apiUrl: 'http://localhost:3000',
        http: httpAdapter,
        storage: MockStorageAdapter(),
      );

      // 1. Test custom code 'SCHEMA_CORRUPT'
      httpAdapter.mockResponse(409, {
        'code': 'SCHEMA_CORRUPT',
        'message': 'Schema is corrupt',
        'activity': 'update',
        'collection_id': 'col-123'
      });

      try {
        await sdk.auth.me('users');
        fail('Should have thrown SdkError');
      } on SdkError catch (error) {
        expect(error.code, equals('SCHEMA_CORRUPT'));
        expect(error.statusCode, equals(409));
        expect(error.details['collection_id'], equals('col-123'));
      }

      // 2. Test custom error_type
      httpAdapter.mockResponse(409, {
        'error_type': 'SCHEMA_CORRUPT_ALT',
        'message': 'Schema is corrupt',
        'activity': 'update'
      });

      try {
        await sdk.auth.me('users');
        fail('Should have thrown SdkError');
      } on SdkError catch (error) {
        expect(error.code, equals('SCHEMA_CORRUPT_ALT'));
        expect(error.statusCode, equals(409));
      }
    });
  });
}
