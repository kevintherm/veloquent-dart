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

  @override
  String toString() {
    return 'SdkError(code: $code, message: $message, statusCode: $statusCode)';
  }
}
