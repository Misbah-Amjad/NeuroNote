import 'dart:typed_data';

import 'package:image_picker_web/image_picker_web.dart';

class PlatformImagePicker {
  static Future<dynamic> pickImage() async {
    return ImagePickerWeb.getImageAsBytes();
  }
}
