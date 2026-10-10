import 'dart:io' as io;

const bool platformIsWeb = false;
bool get platformIsWindows => io.Platform.isWindows;
bool get platformIsLinux => io.Platform.isLinux;
bool get platformIsMacOS => io.Platform.isMacOS;
bool get platformIsAndroid => io.Platform.isAndroid;
bool get platformIsIOS => io.Platform.isIOS;
