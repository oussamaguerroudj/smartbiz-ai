import 'package:file_picker/file_picker.dart';

Future<List<int>?> readFileBytes(PlatformFile file) async {
  return file.bytes;
}
