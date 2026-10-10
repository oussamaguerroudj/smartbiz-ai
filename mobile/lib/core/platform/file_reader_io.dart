import 'dart:io';
import 'package:file_picker/file_picker.dart';

Future<List<int>?> readFileBytes(PlatformFile file) async {
  if (file.bytes != null) return file.bytes;
  if (file.path != null) {
    return await File(file.path!).readAsBytes();
  }
  return null;
}
