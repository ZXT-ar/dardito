import 'package:dardito/app.dart';
import 'package:dardito/core/widgets/book_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 1024.0, 1440.0]) {
    testWidgets('navegación al bajar y subir ($width)', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      int? destination;
      await tester.pumpWidget(
        MaterialApp(
          home: DarditoShell(
            currentIndex: 0,
            onNavigate: (value) => destination = value,
            child: SingleChildScrollView(
              controller: controller,
              child: const SizedBox(height: 2500),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final desktop = width >= 900;
      Offset offset() =>
          tester.widget<AnimatedSlide>(find.byType(AnimatedSlide).first).offset;
      if (desktop) {
        expect(find.byKey(const ValueKey('map-desktop-nav')), findsOneWidget);
        expect(find.byKey(const ValueKey('spine-desktop-nav')), findsNothing);
        final originalY = tester.getTopLeft(find.byType(BookNavigation)).dy;
        controller.jumpTo(40);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byType(BookNavigation)).dy,
          originalY - 40,
        );
      } else {
        expect(offset(), Offset.zero);
      }
      controller.jumpTo(200);
      await tester.pumpAndSettle();
      if (desktop) {
        expect(find.byKey(const ValueKey('map-desktop-nav')), findsNothing);
        expect(find.byKey(const ValueKey('spine-desktop-nav')), findsOneWidget);
      }
      expect(offset().dy, desktop ? -1.5 : 1.5);
      controller.jumpTo(198);
      await tester.pumpAndSettle();
      expect(offset(), Offset.zero);
      await tester.tap(
        desktop ? find.text('Explorar') : find.byIcon(Icons.map_rounded),
      );
      expect(destination, 1);
      controller.jumpTo(220);
      await tester.pumpAndSettle();
      expect(offset().dy, desktop ? -1.5 : 1.5);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      if (desktop) {
        expect(find.byKey(const ValueKey('map-desktop-nav')), findsOneWidget);
        expect(find.byKey(const ValueKey('spine-desktop-nav')), findsNothing);
        expect(find.text('Explorar'), findsOneWidget);
        await tester.tap(find.text('Compartí tu historia'));
        expect(destination, 3);
      } else {
        expect(offset(), Offset.zero);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
