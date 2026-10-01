import 'package:file_picker/file_picker.dart';

import 'image_file_picker_types.dart';

Future<List<PickedImageFile>?> pickImageFiles({
  required bool allowMultiple,
}) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    allowMultiple: allowMultiple,
    withData: true,
  );
  if (result == null) return null;

  final selected = <PickedImageFile>[];
  for (final file in result.files) {
    final bytes = file.bytes;
    if (bytes == null) {
      throw const ImageFilePickerException(
        'El dispositivo no entregó los datos de la imagen seleccionada.',
      );
    }
    selected.add(PickedImageFile(name: file.name, bytes: bytes));
  }
  return selected;
}
