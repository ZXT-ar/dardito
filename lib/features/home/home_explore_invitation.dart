import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

double labelDistance(double width) =>
    math.max(310.0, (width - 1192) / 2 + 215) - 91;

/// Two editorial entrances to the same map, selected by the hero layout.
class HomeExploreInvitation extends StatelessWidget {
  const HomeExploreInvitation({
    super.key,
    required this.compact,
    required this.onTap,
  });
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = compact
        ? AspectRatio(
            aspectRatio: 360 / 205,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _FoldedMapPainter()),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: LayoutBuilder(
                    builder: (context, bounds) => Padding(
                      padding: EdgeInsets.only(
                        left: bounds.maxWidth * .64,
                        right: bounds.maxWidth * .045,
                        top: bounds.maxHeight * .23,
                        bottom: bounds.maxHeight * .13,
                      ),
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explorar\nel mapa',
                              style: TextStyle(
                                fontFamily: 'Lora',
                                fontWeight: FontWeight.w700,
                                fontSize: 25,
                                height: 1.12,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.yellow,
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        : SizedBox(
            height: 340,
            child: LayoutBuilder(
              builder: (context, bounds) {
                final position = Scrollable.maybeOf(context)?.position;
                Widget drawing() {
                  final progress = MediaQuery.disableAnimationsOf(context)
                      ? 1.0
                      : ((position?.pixels ?? 0) / 220).clamp(0.0, 1.0);
                  // The raised label and final needle ray share the same bearing.
                  // Centre y = 249; label centre y = 4 + 24.
                  final targetAngle = math.atan2(
                    labelDistance(bounds.maxWidth),
                    221,
                  );
                  final angle = progress * targetAngle;
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: -169,
                        bottom: -169,
                        width: 520,
                        height: 520,
                        child: CustomPaint(
                          painter: _CompassPainter(angle: angle),
                        ),
                      ),
                      Positioned(
                        left: math.max(
                          310.0,
                          (bounds.maxWidth - 1192) / 2 + 215,
                        ),
                        top: 4,
                        height: 48,
                        child: Row(
                          children: [
                            Text(
                              'Explorar el mapa',
                              style: TextStyle(
                                fontFamily: 'Lora',
                                fontWeight: FontWeight.w700,
                                fontSize: 27,
                                height: 1,
                                color: progress >= .99
                                    ? const Color(0xFF876015)
                                    : AppColors.ink,
                                shadows: progress >= .99
                                    ? [
                                        Shadow(
                                          color: AppColors.yellow.withValues(
                                            alpha: .5,
                                          ),
                                          blurRadius: 18,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF876015),
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return position == null
                    ? drawing()
                    : AnimatedBuilder(
                        animation: position,
                        builder: (_, _) => drawing(),
                      );
              },
            ),
          );
    return Semantics(
      button: true,
      label: 'Explorar el mapa',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: ExcludeSemantics(child: content),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  const _CompassPainter({required this.angle});
  final double angle;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 9;
    final line = Paint()
      ..color = const Color(0xFF746349)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final ratio in [1.0, .965, .80, .69]) {
      canvas.drawCircle(c, r * ratio, line);
    }
    for (var i = 0; i < 120; i++) {
      final a = i * math.pi / 60;
      final outer = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(
        c + outer * (r - 4),
        c + outer * (r - (i % 5 == 0 ? 15 : 8)),
        line,
      );
    }
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * math.pi / 4);
      final length = i.isEven ? r * .67 : r * .48;
      final p = Path()
        ..moveTo(0, -length)
        ..lineTo(14, 0)
        ..lineTo(0, 20)
        ..lineTo(-14, 0)
        ..close();
      canvas.drawPath(
        p,
        Paint()
          ..color = const Color(
            0xFFBAAD90,
          ).withValues(alpha: i.isEven ? .88 : .4),
      );
      canvas.drawPath(
        Path()
          ..moveTo(0, -length)
          ..lineTo(0, 20)
          ..lineTo(-14, 0)
          ..close(),
        Paint()..color = const Color(0xFF535D49),
      );
      canvas.restore();
    }
    for (final entry in [
      ('N', 0.0),
      ('E', math.pi / 2),
      ('S', math.pi),
      ('O', -math.pi / 2),
    ]) {
      final tp = TextPainter(
        text: TextSpan(
          text: entry.$1,
          style: const TextStyle(
            fontFamily: 'Lora',
            fontSize: 25,
            color: Color(0xFF58472F),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final loc = c + Offset(math.sin(entry.$2), -math.cos(entry.$2)) * r * .87;
      tp.paint(canvas, loc - Offset(tp.width / 2, tp.height / 2));
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.drawPath(
      Path()
        ..moveTo(0, -r * .81)
        ..lineTo(17, 12)
        ..lineTo(0, -3)
        ..lineTo(-17, 12)
        ..close(),
      Paint()..color = AppColors.yellow,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, -r * .81)
        ..lineTo(0, -3)
        ..lineTo(-17, 12)
        ..close(),
      Paint()..color = const Color(0xFFB88508),
    );
    canvas.restore();
    canvas.drawCircle(c, 17, Paint()..color = AppColors.cream);
    canvas.drawCircle(c, 6, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(_CompassPainter oldDelegate) => oldDelegate.angle != angle;
}

class _FoldedMapPainter extends CustomPainter {
  const _FoldedMapPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 205);
    final folds = [
      [
        const Offset(6, 42),
        const Offset(77, 63),
        const Offset(77, 190),
        const Offset(6, 168),
      ],
      [
        const Offset(77, 63),
        const Offset(146, 34),
        const Offset(146, 162),
        const Offset(77, 190),
      ],
      [
        const Offset(146, 34),
        const Offset(216, 55),
        const Offset(216, 181),
        const Offset(146, 162),
      ],
      [
        const Offset(216, 55),
        const Offset(349, 31),
        const Offset(355, 167),
        const Offset(216, 181),
      ],
    ];
    for (var i = 0; i < folds.length; i++) {
      final shape = Path()..addPolygon(folds[i], true);
      canvas.drawShadow(shape, Colors.black.withValues(alpha: .4), 5, false);
      canvas.drawPath(
        shape,
        Paint()
          ..color = [
            const Color(0xFFF5EFDF),
            const Color(0xFFD6CFBA),
            const Color(0xFFECE5D2),
            AppColors.cream,
          ][i],
      );
      if (i < 3) {
        canvas.save();
        canvas.clipPath(shape);
        final streets = Paint()
          ..color = const Color(0xFF858978)
          ..strokeWidth = .65
          ..style = PaintingStyle.stroke;
        for (double x = 0; x < 240; x += 13) {
          canvas.drawLine(Offset(x, 25), Offset(x + 25, 200), streets);
        }
        for (double y = 35; y < 205; y += 12) {
          canvas.drawLine(Offset(0, y), Offset(225, y - 18), streets);
        }
        streets
          ..strokeWidth = 3
          ..color = const Color(0xFFB1B19A);
        canvas.drawLine(const Offset(0, 180), const Offset(200, 40), streets);
        canvas.drawLine(const Offset(10, 50), const Offset(220, 175), streets);
        canvas.drawCircle(
          const Offset(110, 105),
          13,
          Paint()..color = const Color(0xFFC2C3A5),
        );
        canvas.restore();
      }
    }
    for (final marker in [
      (const Offset(53, 81), AppColors.yellow),
      (const Offset(125, 45), const Color(0xFF785780)),
      (const Offset(185, 111), AppColors.yellow),
    ]) {
      final tip = marker.$1;
      canvas.drawOval(
        Rect.fromCenter(center: tip + const Offset(2, 2), width: 22, height: 6),
        Paint()..color = Colors.black.withValues(alpha: .18),
      );
      final pin = Path()
        ..moveTo(tip.dx, tip.dy)
        ..cubicTo(
          tip.dx - 7,
          tip.dy - 10,
          tip.dx - 14,
          tip.dy - 16,
          tip.dx - 14,
          tip.dy - 23,
        )
        ..arcToPoint(
          tip + const Offset(14, -23),
          radius: const Radius.circular(14),
        )
        ..cubicTo(
          tip.dx + 14,
          tip.dy - 16,
          tip.dx + 7,
          tip.dy - 10,
          tip.dx,
          tip.dy,
        )
        ..close();
      canvas.drawShadow(pin, Colors.black54, 3, false);
      canvas.drawPath(pin, Paint()..color = marker.$2);
      canvas.drawCircle(
        tip + const Offset(0, -23),
        7,
        Paint()..color = AppColors.cream,
      );
      canvas.drawCircle(
        tip + const Offset(0, -23),
        3,
        Paint()..color = AppColors.ink,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FoldedMapPainter oldDelegate) => false;
}
