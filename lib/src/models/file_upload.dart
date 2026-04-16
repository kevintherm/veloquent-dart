/// Represents a file to be uploaded via multipart/form-data.
///
/// Used when creating or updating records that have fields of type `file`.
/// This wrapper is platform-agnostic — in Flutter you can convert any `XFile`
/// or `dart:io File` by reading its bytes:
///
/// ```dart
/// import 'package:mime/mime.dart';
///
/// final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
/// final upload = FileUpload(
///   bytes: await xfile!.readAsBytes(),
///   filename: xfile.name,
///   mimeType: lookupMimeType(xfile.name) ?? 'application/octet-stream',
/// );
/// ```
class FileUpload {
  const FileUpload({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  /// Raw file bytes.
  final List<int> bytes;

  /// The original filename (e.g. `'photo.jpg'`). Sent as the
  /// `filename` part of the multipart field.
  final String filename;

  /// The MIME type of the file (e.g. `'image/jpeg'`).
  final String mimeType;

  @override
  String toString() => 'FileUpload(filename: $filename, mimeType: $mimeType, bytes: ${bytes.length}B)';
}
