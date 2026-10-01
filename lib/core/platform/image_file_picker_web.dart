import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

import 'image_file_picker_types.dart';

const _acceptedImageTypes = '.jpg,.jpeg,.png,.webp';

Future<List<PickedImageFile>?> pickImageFiles({
  required bool allowMultiple,
}) async {
  final input = HTMLInputElement()
    ..type = 'file'
    ..accept = _acceptedImageTypes
    ..multiple = allowMultiple;
  input.style
    ..position = 'fixed'
    ..left = '-10000px'
    ..width = '1px'
    ..height = '1px'
    ..opacity = '0';

  final completer = Completer<List<PickedImageFile>?>();
  late EventListener changeListener;
  late EventListener cancelListener;

  void completeOnce(List<PickedImageFile>? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  void completeErrorOnce(Object error, StackTrace stackTrace) {
    if (!completer.isCompleted) completer.completeError(error, stackTrace);
  }

  Future<void> readSelection() async {
    try {
      final files = input.files;
      if (files == null || files.length == 0) {
        completeOnce(null);
        return;
      }

      final selected = <PickedImageFile>[];
      for (var index = 0; index < files.length; index++) {
        final file = files.item(index);
        if (file == null) continue;
        selected.add(
          PickedImageFile(name: file.name, bytes: await _readFile(file)),
        );
      }
      completeOnce(selected);
    } catch (error, stackTrace) {
      completeErrorOnce(
        const ImageFilePickerException(
          'El navegador no pudo leer la imagen seleccionada.',
        ),
        stackTrace,
      );
    }
  }

  changeListener = ((Event _) {
    unawaited(readSelection());
  }).toJS;
  cancelListener = ((Event _) {
    completeOnce(null);
  }).toJS;

  input.addEventListener('change', changeListener);
  input.addEventListener('cancel', cancelListener);
  document.body?.appendChild(input);
  input.click();

  try {
    return await completer.future;
  } finally {
    input.removeEventListener('change', changeListener);
    input.removeEventListener('cancel', cancelListener);
    input.parentNode?.removeChild(input);
  }
}

Future<Uint8List> _readFile(File file) {
  final completer = Completer<Uint8List>();
  final reader = FileReader();

  reader.addEventListener(
    'load',
    ((Event _) {
      if (completer.isCompleted) return;
      final buffer = (reader.result as JSArrayBuffer?)?.toDart;
      if (buffer == null) {
        completer.completeError(
          const ImageFilePickerException(
            'La imagen seleccionada no contiene datos legibles.',
          ),
        );
        return;
      }
      completer.complete(buffer.asUint8List());
    }).toJS,
  );
  reader.addEventListener(
    'error',
    ((Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          const ImageFilePickerException(
            'Ocurrió un error al leer la imagen seleccionada.',
          ),
        );
      }
    }).toJS,
  );
  reader.addEventListener(
    'abort',
    ((Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          const ImageFilePickerException('La lectura fue cancelada.'),
        );
      }
    }).toJS,
  );
  reader.readAsArrayBuffer(file);
  return completer.future;
}
