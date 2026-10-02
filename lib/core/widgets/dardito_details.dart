import 'package:flutter/material.dart';

/// Small motifs taken from Dardito's leaves, bookmark and cover clasp.
class DarditoDetail extends StatelessWidget {
  const DarditoDetail({
    super.key,
    this.ribbon = false,
    this.clasp = false,
    this.size = 24,
  });
  final bool ribbon, clasp;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: CustomPaint(
        size: Size(size, ribbon ? size * 1.6 : size),
        painter: _DetailPainter(ribbon, clasp),
      ),
    ),
  );
}

class _DetailPainter extends CustomPainter {
  const _DetailPainter(this.ribbon, this.clasp);
  final bool ribbon, clasp;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / (ribbon ? 38 : 24));
    if (ribbon) {
      final shape = Path()
        ..moveTo(3, 0)
        ..lineTo(21, 0)
        ..lineTo(21, 38)
        ..lineTo(12, 30)
        ..lineTo(3, 38)
        ..close();
      canvas.drawPath(
        shape,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF526126), Color(0xFF9AA34D), Color(0xFF65742A)],
          ).createShader(const Rect.fromLTWH(3, 0, 18, 38)),
      );
      canvas.drawLine(
        const Offset(6, 2),
        const Offset(6, 32),
        Paint()
          ..color = const Color(0xFFB5BC76)
          ..strokeWidth = .6,
      );
      return;
    }
    if (clasp) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(1, 1, 22, 22),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF383B2F),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(3, 3, 18, 18),
          const Radius.circular(1),
        ),
        Paint()
          ..color = const Color(0xFF71654A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6,
      );
      canvas.translate(4, 4);
      canvas.scale(.67);
    }
    final green = clasp ? const Color(0xFFD49A32) : const Color(0xFF788B39);
    for (final left in [true, false]) {
      canvas.save();
      if (left) {
        canvas.translate(24, 0);
        canvas.scale(-1, 1);
      }
      final leaf = Path()
        ..moveTo(12, 21)
        ..cubicTo(10, 11, 15, 4, 23, 2)
        ..cubicTo(24, 11, 21, 18, 12, 21)
        ..close();
      canvas.drawPath(leaf, Paint()..color = green);
      canvas.drawLine(
        const Offset(12, 21),
        const Offset(21, 5),
        Paint()
          ..color = (clasp ? const Color(0xFF805719) : const Color(0xFF43521C))
          ..strokeWidth = .8,
      );
      canvas.restore();
    }
    canvas.drawLine(
      const Offset(12, 18),
      const Offset(12, 24),
      Paint()
        ..color = green
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_DetailPainter old) =>
      old.ribbon != ribbon || old.clasp != clasp;
}
