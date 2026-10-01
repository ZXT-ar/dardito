import 'package:dardito/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'navegación se oculta al bajar y vuelve con 2px de subida ($width)',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: DarditoShell(
              currentIndex: 0,
              onNavigate: (_) {},
              child: SingleChildScrollView(
                controller: controller,
                child: const SizedBox(height: 2500),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Offset offset() =>
            tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset;
        expect(offset(), Offset.zero);
        controller.jumpTo(200);
        await tester.pumpAndSettle();
        expect(offset().dy, width < 1000 ? 1.5 : -1.5);
        controller.jumpTo(198);
        await tester.pumpAndSettle();
        expect(offset(), Offset.zero);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
