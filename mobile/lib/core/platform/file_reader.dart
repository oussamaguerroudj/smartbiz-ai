import 'package:file_picker/file_picker.dart';
import 'file_reader_stub.dart'
    if (dart.library.io) 'file_reader_io.dart'
    if (dart.library.js_interop) 'file_reader_web.dart';

abstract class AppFileReader {
  static Future<List<int>?> getFileBytes(PlatformFile file) => readFileBytes(file);
}
