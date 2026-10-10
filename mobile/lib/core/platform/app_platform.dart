import 'app_platform_stub.dart'
    if (dart.library.io) 'app_platform_io.dart'
    if (dart.library.js_interop) 'app_platform_web.dart';

abstract class AppPlatform {
  static bool get isWeb => platformIsWeb;
  static bool get isWindows => platformIsWindows;
  static bool get isLinux => platformIsLinux;
  static bool get isMacOS => platformIsMacOS;
  static bool get isAndroid => platformIsAndroid;
  static bool get isIOS => platformIsIOS;
  static bool get isDesktop => isWindows || isLinux || isMacOS;
}
