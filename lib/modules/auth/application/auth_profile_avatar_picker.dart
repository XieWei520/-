import '../../../core/platform/local_image_picker.dart';

typedef AuthProfileAvatarPicker = Future<String?> Function();

AuthProfileAvatarPicker createAuthProfileAvatarPicker() {
  return () async {
    return pickSingleLocalImagePath(imageQuality: 85, maxWidth: 1024);
  };
}
