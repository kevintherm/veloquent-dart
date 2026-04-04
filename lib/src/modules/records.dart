import '../core/request.dart';
import '../models/record.dart';
import '../models/records_list_result.dart';

class Records {
  Records(this.requestHelper);

  final RequestHelper requestHelper;

  Future<RecordsListResult> list(String collection,
      {String? filter,
      String? sort,
      int? perPage,
      int? page,
      String? expand}) async {
    final query = <String, dynamic>{};
    if (filter != null) query['filter'] = filter;
    if (sort != null) query['sort'] = sort;
    if (perPage != null) query['per_page'] = perPage.toString();
    if (page != null) query['page'] = page.toString();
    if (expand != null) query['expand'] = expand;

    final result = await requestHelper.execute(
      method: 'GET',
      path: '/collections/$collection/records',
      query: query,
    );

    final List<dynamic> rawData = result.data;
    final List<Record> data = rawData
        .map((item) => Record(collection, Map<String, dynamic>.from(item)))
        .toList();
    return RecordsListResult(data: data, meta: result.meta);
  }

  Future<Record> create(
      String collection, Map<String, dynamic> data) async {
    final result = await requestHelper.execute(
      method: 'POST',
      path: '/collections/$collection/records',
      body: data,
    );

    return Record(collection, Map<String, dynamic>.from(result.data));
  }

  Future<Record> get(String collection, String id,
      {String? expand}) async {
    final query = <String, dynamic>{};
    if (expand != null) query['expand'] = expand;

    final result = await requestHelper.execute(
      method: 'GET',
      path: '/collections/$collection/records/$id',
      query: query.isEmpty ? null : query,
    );

    return Record(collection, Map<String, dynamic>.from(result.data));
  }

  Future<Record> update(
      String collection, String id, Map<String, dynamic> data) async {
    final result = await requestHelper.execute(
      method: 'PATCH',
      path: '/collections/$collection/records/$id',
      body: data,
    );

    return Record(collection, Map<String, dynamic>.from(result.data));
  }

  Future<void> delete(String collection, String id) async {
    await requestHelper.execute(
      method: 'DELETE',
      path: '/collections/$collection/records/$id',
    );
  }
}
