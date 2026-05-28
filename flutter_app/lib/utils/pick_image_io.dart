/// Native (Android / iOS / desktop) implementation using the file_picker package.
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<({Uint8List bytes, String mime})?> pickImageFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.first;
  final bytes = file.bytes ??
      (file.path != null ? await File(file.path!).readAsBytes() : null);
  if (bytes == null) return null;

  final ext = (file.extension ?? 'jpg').toLowerCase();
  final mime = ext == 'png'
      ? 'image/png'
      : ext == 'webp'
          ? 'image/webp'
          : 'image/jpeg';

  return (bytes: bytes, mime: mime);
}
