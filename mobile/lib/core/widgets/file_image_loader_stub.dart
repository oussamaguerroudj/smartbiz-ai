import 'package:flutter/material.dart';

Widget loadFileImage({
  required String filePath,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? errorWidget,
}) {
  return errorWidget ??
      SizedBox(
        width: width,
        height: height,
        child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
      );
}
