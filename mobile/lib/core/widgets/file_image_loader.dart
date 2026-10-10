import 'package:flutter/widgets.dart';
import 'file_image_loader_stub.dart'
    if (dart.library.io) 'file_image_loader_io.dart';

Widget buildFileImage({
  required String filePath,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? errorWidget,
}) {
  return loadFileImage(
    filePath: filePath,
    width: width,
    height: height,
    fit: fit,
    errorWidget: errorWidget,
  );
}
