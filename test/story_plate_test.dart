import 'dart:ui' as ui;
import 'package:dardito/core/theme/app_theme.dart';
import 'package:dardito/features/assistant/story_plate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<MemoryImage> fixture(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = AppColors.green,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return MemoryImage(bytes!.buffer.asUint8List());
}

void main() {
  for (final size in [
    const Size(320, 700),
    const Size(768, 900),
    const Size(1440, 1000),
  ]) {
    for (final portrait in [true, false]) {
      testWidgets(
        'lámina y ampliación sin recorte ${size.width} portrait=$portrait',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final provider = await tester.runAsync(
            () => fixture(portrait ? 300 : 600, portrait ? 450 : 300),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: StoryPlate(
                      image: provider!,
                      title: 'Imagen de El duende de Los Hornos',
                      leading: const Text('Texto completo de la historia.'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pumpAndSettle();
          expect(find.text('LÁMINA 01'), findsOneWidget);
          expect(find.text('Texto completo de la historia.'), findsOneWidget);
          expect(
            find.byKey(
              ValueKey(
                (portrait && size.width >= 768) || size.width >= 1440
                    ? 'story-text-beside-image'
                    : 'story-image-below-text',
              ),
            ),
            findsOneWidget,
          );
          expect(find.text('El duende de Los Hornos'), findsOneWidget);
          final photoSize = tester.getSize(find.byType(Image));
          expect(
            photoSize.width / photoSize.height,
            closeTo(portrait ? 2 / 3 : 2, .01),
          );
          if (portrait && size.width > 700)
            expect(photoSize.width, lessThan(300));
          await tester.tap(find.byType(InkWell));
          await tester.pumpAndSettle();
          expect(find.byType(InteractiveViewer), findsOneWidget);
          final dialogSize = tester.getSize(find.byType(Dialog));
          expect(dialogSize.width, lessThanOrEqualTo(size.width));
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Cerrar imagen'));
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
        },
      );
    }
  }
}
