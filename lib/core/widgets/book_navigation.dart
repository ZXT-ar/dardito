import 'package:flutter/material.dart';

/// Ink on the opening map; gilt lettering on the returning book spine.
class BookNavigation extends StatelessWidget {
  const BookNavigation({
    super.key,
    required this.onNavigate,
    this.spine = false,
  });
  final ValueChanged<int> onNavigate;
  final bool spine;
  static const labels = [
    'Inicio',
    'Explorar',
    'Preguntale a Dardito',
    'Compartí tu historia',
  ];
  static const icons = [
    Icons.home_rounded,
    Icons.map_rounded,
    Icons.chat_bubble_rounded,
    Icons.add_circle_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final ink = spine ? const Color(0xFFF0DEAD) : const Color(0xFF463D29);
    final content = SizedBox(
      height: 76,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: LayoutBuilder(
          builder: (context, bounds) => Row(
            children: [
              Semantics(
                header: true,
                child: Row(
                  children: [
                    Icon(Icons.menu_book_outlined, color: ink, size: 30),
                    if (bounds.maxWidth > 960) ...[
                      const SizedBox(width: 12),
                      Text(
                        'El Mapa de las\nHistorias de La Plata',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          color: ink,
                          fontSize: 13,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        for (var i = 0; i < labels.length; i++)
                          _InkLink(
                            label: labels[i],
                            icon: icons[i],
                            ink: ink,
                            selected: i == 0,
                            spine: spine,
                            onTap: () => onNavigate(i),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      label: spine ? 'Navegación del libro' : 'Navegación sobre el mapa',
      child: spine
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF24382F),
                    Color(0xFF435345),
                    Color(0xFF304538),
                    Color(0xFF1E3028),
                  ],
                  stops: [0, .22, .68, 1],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x330D1710),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: CustomPaint(painter: _SpineTooling(), child: content),
            )
          : content,
    );
  }
}

class _InkLink extends StatefulWidget {
  const _InkLink({
    required this.label,
    required this.icon,
    required this.ink,
    required this.selected,
    required this.spine,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color ink;
  final bool selected, spine;
  final VoidCallback onTap;
  @override
  State<_InkLink> createState() => _InkLinkState();
}

class _InkLinkState extends State<_InkLink> {
  bool hover = false, focus = false;
  @override
  Widget build(BuildContext context) {
    final active = hover || focus;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final color = active
        ? (widget.spine ? const Color(0xFFFFE5A0) : const Color(0xFF94671B))
        : widget.ink;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => hover = value),
          onFocusChange: (value) => setState(() => focus = value),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
            child: AnimatedSlide(
              duration: duration,
              offset: active ? const Offset(0, -.05) : Offset.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedRotation(
                        turns: active ? -.035 : 0,
                        duration: duration,
                        child: Icon(widget.icon, size: 18, color: color),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      end: active
                          ? 1
                          : widget.selected
                          ? .35
                          : 0,
                    ),
                    duration: duration,
                    builder: (context, value, _) => CustomPaint(
                      size: const Size(100, 3),
                      painter: _InkUnderline(color, value),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InkUnderline extends CustomPainter {
  const _InkUnderline(this.color, this.progress);
  final Color color;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(0, 1.5)
      ..quadraticBezierTo(size.width * .4, 0, size.width, 1);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_InkUnderline old) =>
      old.color != color || old.progress != progress;
}

class _SpineTooling extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gilt = Paint()
      ..color = const Color(0xFFB8A16B).withValues(alpha: .65)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;
    // Paired rules and raised binding bands suggest the spine, not a card.
    for (final y in [7.0, 10.0, size.height - 10, size.height - 7]) {
      canvas.drawLine(Offset(15, y), Offset(size.width - 15, y), gilt);
    }
    for (final x in [12.0, 18.0, size.width - 18, size.width - 12]) {
      canvas.drawLine(
        Offset(x, 4),
        Offset(x, size.height - 4),
        gilt..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(_SpineTooling old) => false;
}
