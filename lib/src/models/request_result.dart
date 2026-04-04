class RequestResult<T> {
  const RequestResult({
    required this.data,
    this.meta,
    this.message,
  });

  final T data;
  final Map<String, dynamic>? meta;
  final String? message;
}
