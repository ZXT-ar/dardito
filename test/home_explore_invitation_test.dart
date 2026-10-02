import 'dart:math' as math;
import 'package:dardito/core/theme/app_theme.dart';
import 'package:dardito/features/home/home_explore_invitation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la aguja sigue el scroll, limita el giro y vuelve al norte', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                HomeExploreInvitation(compact: false, onTap: () {}),
                const SizedBox(height: 1600),
              ],
            ),
          ),
        ),
      ),
    );
    double angle() {
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .firstWhere((p) => p.runtimeType.toString() == '_CompassPainter');
      return (painter as dynamic).angle as double;
    }

    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
    expect(angle(), 0);
    expect(
      tester.widget<Text>(find.text('Explorar el mapa')).style?.color,
      AppColors.ink,
    );
    controller.jumpTo(110);
    await tester.pump();
    expect(angle(), closeTo(math.atan2(labelDistance(800), 221) / 2, .001));
    controller.jumpTo(220);
    await tester.pump();
    expect(angle(), closeTo(math.atan2(labelDistance(800), 221), .001));
    expect(
      tester.widget<Text>(find.text('Explorar el mapa')).style?.color,
      const Color(0xFF876015),
    );
    controller.jumpTo(0);
    await tester.pump();
    expect(angle(), 0);
    expect(
      tester.widget<Text>(find.text('Explorar el mapa')).style?.color,
      AppColors.ink,
    );
    expect(tester.takeException(), isNull);
  });
  for (final compact in [true, false]) {
    testWidgets('abre el mapa desde la variante compacta=$compact', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: compact ? 272 : 1000,
              child: HomeExploreInvitation(
                compact: compact,
                onTap: () => opened++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
