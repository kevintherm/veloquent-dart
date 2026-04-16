import '../core/request.dart';
import '../models/file_upload.dart';
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

  /// Create a new record in a collection.
  ///
  /// If [data] contains any [FileUpload] values, the request is automatically
  /// sent as `multipart/form-data`. Otherwise it is sent as JSON.
  ///
  /// ```dart
  /// // Plain JSON
  /// await sdk.records.create('posts', {'title': 'Hello'});
  ///
  /// // With a file
  /// await sdk.records.create('users', {
  ///   'name': 'avatar',
  ///   'avatar': FileUpload(
  ///     bytes: imageBytes,
  ///     filename: 'avatar.jpg',
  ///     mimeType: 'image/jpeg',
  ///   ),
  /// });
  ///
  /// // With multiple files
  /// await sdk.records.create('posts', {
  ///   'title': 'My Trip',
  ///   'gallery': [upload1, upload2],
  /// });
  /// ```
  Future<Record> create(String collection, Map<String, dynamic> data) async {
    final result = await requestHelper.execute(
      method: 'POST',
      path: '/collections/$collection/records',
      body: data,
    );

    return Record(collection, Map<String, dynamic>.from(result.data));
  }

  Future<Record> get(String collection, String id, {String? expand}) async {
    final query = <String, dynamic>{};
    if (expand != null) query['expand'] = expand;

    final result = await requestHelper.execute(
      method: 'GET',
      path: '/collections/$collection/records/$id',
      query: query.isEmpty ? null : query,
    );

    return Record(collection, Map<String, dynamic>.from(result.data));
  }

  /// Update a record.
  ///
  /// If [data] contains any [FileUpload] values, the request is automatically
  /// sent as `multipart/form-data`.
  ///
  /// For fields that allow multiple files you can use the `+` and `-` key
  /// suffixes to append or remove files without replacing the entire field:
  ///
  /// ```dart
  /// // Replace the avatar
  /// await sdk.records.update('users', id, {
  ///   'avatar': FileUpload(bytes: bytes, filename: 'new.jpg', mimeType: 'image/jpeg'),
  /// });
  ///
  /// // Append to a multi-file gallery
  /// await sdk.records.update('posts', id, {
  ///   'gallery+': [FileUpload(bytes: bytes, filename: 'extra.jpg', mimeType: 'image/jpeg')],
  /// });
  ///
  /// // Remove a file by its stored path
  /// await sdk.records.update('posts', id, {
  ///   'gallery-': [{'path': 'collections/posts/abc.jpg'}],
  /// });
  /// ```
  Future<Record> update(String collection, String id, Map<String, dynamic> data) async {
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
