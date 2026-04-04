import '../core/request.dart';

class Collections {
  Collections(this.requestHelper);

  final RequestHelper requestHelper;

  Future<List<Map<String, dynamic>>> list(
      {String? filter, String? sort, String? expand}) async {
    final query = <String, dynamic>{};
    if (filter != null) query['filter'] = filter;
    if (sort != null) query['sort'] = sort;
    if (expand != null) query['expand'] = expand;

    final result = await requestHelper.execute(
      method: 'GET',
      path: '/collections',
      query: query,
    );

    return List<Map<String, dynamic>>.from(result.data);
  }

  Future<Map<String, dynamic>> get(String collection) async {
    final result = await requestHelper.execute(
      method: 'GET',
      path: '/collections/$collection',
    );

    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final result = await requestHelper.execute(
      method: 'POST',
      path: '/collections',
      body: data,
    );

    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> update(
      String collection, Map<String, dynamic> data) async {
    final result = await requestHelper.execute(
      method: 'PATCH',
      path: '/collections/$collection',
      body: data,
    );

    return Map<String, dynamic>.from(result.data);
  }

  Future<void> delete(String collection) async {
    await requestHelper.execute(
      method: 'DELETE',
      path: '/collections/$collection',
    );
  }

  Future<Map<String, dynamic>> truncate(String collection) async {
    final result = await requestHelper.execute(
      method: 'DELETE',
      path: '/collections/$collection/truncate',
    );

    return Map<String, dynamic>.from(result.data);
  }
}
