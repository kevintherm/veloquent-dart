class Record {
  Record(this.collection, this._data);

  /// The collection this record belongs to.
  final String collection;

  /// The raw record data as returned by the API.
  final Map<String, dynamic> _data;

  /// Returns the value of a field of this record.
  dynamic get(String field) => _data[field];

  /// Sets the value of a field of this record.
  void set(String field, dynamic value) => _data[field] = value;

  /// Returns the ID of the record.
  String? get id => _data['id']?.toString();

  /// Returns the creation date of the record.
  DateTime? get createdAt => _data['created_at'] != null ? DateTime.tryParse(_data['created_at'].toString()) : null;

  /// Returns the last update date of the record.
  DateTime? get updatedAt => _data['updated_at'] != null ? DateTime.tryParse(_data['updated_at'].toString()) : null;

  /// Returns a copy of the raw record data.
  Map<String, dynamic> toMap() => Map<String, dynamic>.from(_data);

  @override
  String toString() => 'Record($collection, $_data)';
}
