import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import '../domain/user_profile.dart';

/// Lets the user pick a photo and returns it as a small base64 JPEG, or null
/// if they cancelled. The picker shrinks it (400 px, quality 70, about
/// 30–60 KB) so it fits in the `users/{uid}` document.
///
/// Throws [ArgumentError] if the result is still too large.
typedef ProfilePhotoPicker = Future<String?> Function(ImageSource source);

Future<String?> pickProfilePhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 400,
    maxHeight: 400,
    imageQuality: 70,
  );
  if (file == null) {
    return null;
  }
  final encoded = base64Encode(await file.readAsBytes());
  if (encoded.length > maxProfilePhotoLength) {
    throw ArgumentError('Photo is too large');
  }
  return encoded;
}
