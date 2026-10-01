import 'dart:typed_data';

class PickedImageFile {
  const PickedImageFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class ImageFilePickerException implements Exception {
  const ImageFilePickerException(this.message);

  final String message;

  @override
  String toString() => message;
}
