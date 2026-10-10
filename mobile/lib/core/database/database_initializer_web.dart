import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<String> initPlatformDatabase(String filename) async {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
  return filename;
}
