import '../core/request.dart';

class Schema {
  Schema(this.requestHelper);

  final RequestHelper requestHelper;

  Future<List<Map<String, dynamic>>> corrupt() async {
    final result = await requestHelper.execute(
      method: 'GET',
      path: '/schema/corrupt',
    );

    return List<Map<String, dynamic>>.from(result.data);
  }

  Future<List<String>> orphans() async {
    final result = await requestHelper.execute(
      method: 'GET',
      path: '/schema/orphans',
    );

    return List<String>.from(result.data);
  }

  Future<void> dropOrphans() async {
    await requestHelper.execute(
      method: 'DELETE',
      path: '/schema/orphans',
    );
  }

  Future<void> dropOrphan(String tableName) async {
    await requestHelper.execute(
      method: 'DELETE',
      path: '/schema/orphans/${Uri.encodeComponent(tableName)}',
    );
  }

  Future<Map<String, dynamic>> transferExport(
      [Map<String, dynamic>? body]) async {
    final result = await requestHelper.execute(
      method: 'POST',
      path: '/schema/transfer/export',
      body: body ?? <String, dynamic>{},
    );

    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> transferImport(Map<String, dynamic> body) async {
    final result = await requestHelper.execute(
      method: 'POST',
      path: '/schema/transfer/import',
      body: body,
    );

    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> transferOptions() async {
    final result = await requestHelper.execute(
      method: 'GET',
      path: '/schema/transfer/options',
    );

    return Map<String, dynamic>.from(result.data);
  }
}
