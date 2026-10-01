import 'image_file_picker_stub.dart'
    if (dart.library.js_interop) 'image_file_picker_web.dart'
    as implementation;
import 'image_file_picker_types.dart';

export 'image_file_picker_types.dart';

Future<List<PickedImageFile>?> pickImageFiles({required bool allowMultiple}) =>
    implementation.pickImageFiles(allowMultiple: allowMultiple);
