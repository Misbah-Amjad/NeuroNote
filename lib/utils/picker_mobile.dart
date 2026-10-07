import 'package:image_picker/image_picker.dart';

class PlatformImagePicker {
  static Future<dynamic> pickImage() async {
    final picker = ImagePicker();
    return await picker.pickImage(source: ImageSource.gallery);
  }
}
