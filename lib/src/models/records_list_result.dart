import 'record.dart';

class RecordsListResult {
  const RecordsListResult({
    required this.data,
    this.meta,
  });

  final List<Record> data;
  final Map<String, dynamic>? meta;
}
