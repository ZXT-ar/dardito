import 'package:dardito/features/home/home_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'revela las letras en orden sin cambiar el tamaño y no reinicia',
    (tester) async {
      const style = TextStyle(fontSize: 37, color: Colors.black);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DarditoAnimatedName(style: style)),
        ),
      );
      final finder = find.byType(Text).first;
      final initialSize = tester.getSize(finder);
      List<double> opacity() =>
          (tester.widget<Text>(finder).textSpan! as TextSpan).children!
              .cast<TextSpan>()
              .map((s) => s.style!.color!.a)
              .toList();
      expect(opacity(), everyElement(0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 950));
      expect(opacity().first, 1);
      expect(opacity().last, 0);
      expect(tester.getSize(finder), initialSize);
      await tester.pumpAndSettle();
      expect(opacity(), everyElement(1));
      await tester.pump(const Duration(seconds: 3));
      expect(opacity(), everyElement(1));
    },
  );
  testWidgets('movimiento reducido muestra el contenido completo sin demora', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: DarditoAnimatedName(style: TextStyle(color: Colors.black)),
          ),
        ),
      ),
    );
    final span =
        tester.widget<Text>(find.byType(Text).first).textSpan! as TextSpan;
    expect(
      span.children!.cast<TextSpan>().map((s) => s.style!.color!.a),
      everyElement(1),
    );
    expect(tester.hasRunningAnimations, false);
  });
}
