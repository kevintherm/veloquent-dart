class SdkError implements Exception {
  SdkError(
    this.code,
    this.message, {
    this.statusCode,
    this.details,
    this.cause,
  });

  final String code;
  final String message;
  final int? statusCode;
  final dynamic details;
  final Object? cause;

  bool isRetryable() {
    final code = statusCode;
    return code != null && code >= 500;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': 'SdkError',
      'code': code,
      'message': message,
      'statusCode': statusCode,
      'details': details,
    };
  }

  /// Returns a list of error messages for a specific field if available.
  List<String> getFieldErrors(String field) {
    if (details is Map) {
      final errors = details[field];
      if (errors is List) {
        return errors.map((e) => e.toString()).toList();
      }
      if (errors != null) {
        return [errors.toString()];
      }
    }
    return [];
  }

  /// Returns the first error message for a specific field if available.
  String? getFirstFieldError(String field) {
    final errors = getFieldErrors(field);
    return errors.isNotEmpty ? errors.first : null;
  }


  @override
  String toString() {
    return 'SdkError(code: $code, message: $message, statusCode: $statusCode)';
  }
}
