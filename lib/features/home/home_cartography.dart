import '../../core/theme/site_palette.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/story.dart';
import 'home_explore_invitation.dart';

const tiloInk = Color(0xFF536044);

/// One projection for streets, park boundaries and story coordinates.
/// The source capture uses MapLibre's 512px Mercator world, bearing 42.1°.
class HomeMapProjection {
  HomeMapProjection(this.size, this.sectionTop, this.sectionHeight);
  final Size size;
  final double sectionTop, sectionHeight;
  double get scale => math.max(size.width / 3840, size.height / 2160);
  Offset get anchor => Offset(
    size.width * (size.width < 1050 ? .52 : .72),
    sectionTop + sectionHeight * (size.width < 1050 ? .70 : .43),
  );
  Offset source(Offset p) => anchor + (p - Offset(1920, 1080)) * scale;
  static Offset project(double latitude, double longitude) {
    final world = 512 * 11585.237502960395; // 2^13.5
    double mercator(double lat) {
      final s = math.sin(lat * math.pi / 180);
      return .5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
    }

    final dx = (longitude + 57.954) / 360 * world;
    final dy = (mercator(latitude) - mercator(-34.9205)) * world;
    final b = 42.1 * math.pi / 180;
    return Offset(
      1920 + dx * math.cos(b) + dy * math.sin(b),
      1080 - dx * math.sin(b) + dy * math.cos(b),
    );
  }

  Offset location(double latitude, double longitude) =>
      source(project(latitude, longitude));
}

class HomeCartography extends StatefulWidget {
  const HomeCartography({
    super.key,
    required this.hero,
    required this.stories,
    required this.onExplore,
  });
  final Widget hero;
  final List<CityStory> stories;
  final ValueChanged<CityStory?> onExplore;
  @override
  State<HomeCartography> createState() => _HomeCartographyState();
}

class _HomeCartographyState extends State<HomeCartography> {
  final _heroKey = GlobalKey();
  double _heroHeight = 796;
  _MapGeometry? _geometry;
  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/map/home_cartography.json').then((source) {
      if (mounted) setState(() => _geometry = _MapGeometry.decode(source));
    });
  }

  void _measure() {
    final box = _heroKey.currentContext?.findRenderObject() as RenderBox?;
    if (mounted &&
        box != null &&
        box.hasSize &&
        (box.size.height - _heroHeight).abs() > 1) {
      setState(() => _heroHeight = box.size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final scroll = Scrollable.maybeOf(context)?.position;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final narrow = width < 1050;
        final copyWidth = narrow ? width - 48 : math.min(440.0, width * .36);
        final headingStyle = Theme.of(context).textTheme.displayMedium!
            .copyWith(fontSize: narrow ? 35 : 46, height: 1.08);
        final bodyStyle = Theme.of(
          context,
        ).textTheme.bodyLarge!.copyWith(height: 1.55);
        double measure(String text, TextStyle style) {
          final p = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: copyWidth);
          final height = p.height;
          p.dispose();
          return height;
        }

        final copyHeight =
            measure('Cada punto guarda\nalgo para contar.', headingStyle) +
            measure(
              'Recorré La Plata por barrio, época o curiosidad. Historias documentadas y memorias de quienes la habitan.',
              bodyStyle,
            ) +
            175;
        final sectionHeight = math.max(
          narrow ? 830.0 : 600.0,
          copyHeight + (narrow ? 520 : 225),
        );
        final margin = narrow ? 24.0 : math.max(54.0, (width - 1192) / 2 + 32);
        final viewport = MediaQuery.sizeOf(context).height;
        final reduced = MediaQuery.disableAnimationsOf(context);
        Widget scene() {
          final pixels = scroll?.pixels ?? 0;
          final end = math.max(440.0, _heroHeight - viewport * .35);
          final turn = reduced
              ? 1.0
              : ((pixels - 170) / (end - 170)).clamp(0.0, 1.0);
          final active = turn >= .97;
          final compassSize = narrow ? 240.0 : 450.0;
          final compassCenter = Offset(
            narrow ? 70 : 120,
            _heroHeight - (narrow ? 60 : 130),
          );
          final heading = Offset(
            margin + (narrow ? 100 : 120),
            _heroHeight + (narrow ? 170 : 245),
          );
          final headingAngle = math.atan2(
            heading.dx - compassCenter.dx,
            compassCenter.dy - heading.dy,
          );
          final firstTurn = (pixels / 170).clamp(0.0, 1.0) * .7;
          final angle = firstTurn * (1 - turn) + headingAngle * turn;
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: reduced ? 0 : 800),
            curve: Curves.easeOutCubic,
            tween: Tween(end: active ? 1 : 0),
            builder: (context, reveal, _) => SizedBox(
              width: width,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, frame) {
                        final projection = HomeMapProjection(
                          frame.biggest,
                          _heroHeight,
                          sectionHeight,
                        );
                        final mapArea = Rect.fromLTRB(
                          narrow ? 30 : width * .49,
                          _heroHeight + (narrow ? copyHeight + 115 : 35),
                          width - (narrow ? 30 : 70),
                          _heroHeight + sectionHeight - 75,
                        );
                        final points = <(CityStory, Offset)>[];
                        // Stable editorial selection, with real coordinates and collision avoidance.
                        final candidates = [...widget.stories]
                          ..sort((a, b) => a.id.compareTo(b.id));
                        for (final story in candidates) {
                          final p = projection.location(
                            story.latitude,
                            story.longitude,
                          );
                          if (mapArea.contains(p) &&
                              points.every(
                                (v) =>
                                    (v.$2 - p).distance > (narrow ? 95 : 135),
                              )) {
                            points.add((story, p));
                            if (points.length == (narrow ? 3 : 5)) break;
                          }
                        }
                        points.sort((a, b) => a.$2.dy.compareTo(b.$2.dy));
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  key: ValueKey('continuous-home-map'),
                                  painter: _CartographyPainter(
                                    SitePalette.of(context).dark,
                                    _geometry,
                                    projection,
                                    reveal,
                                    points.map((e) => e.$2).toList(),
                                  ),
                                ),
                              ),
                            ),
                            // Paper wash is continuous too; no section boundary or repeated image.
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: [0, .38, .66, .88, 1],
                                      colors: [
                                        SitePalette.of(
                                          context,
                                        ).canvas.withValues(alpha: .64),
                                        SitePalette.of(
                                          context,
                                        ).canvas.withValues(alpha: .42),
                                        SitePalette.of(
                                          context,
                                        ).canvas.withValues(alpha: .02),
                                        SitePalette.of(
                                          context,
                                        ).canvas.withValues(alpha: .05),
                                        SitePalette.of(context).canvas,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      stops: [0, .36, .62, 1],
                                      colors: [
                                        SitePalette.of(
                                          context,
                                        ).canvas.withValues(alpha: .82),
                                        SitePalette.of(
                                          context,
                                        ).canvas.withValues(alpha: .70),
                                        SitePalette.of(
                                          context,
                                        ).canvas.withValues(alpha: 0),
                                        SitePalette.of(
                                          context,
                                        ).canvas.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (narrow)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: _heroHeight + 70,
                                height: copyHeight + 50,
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        stops: [0, .15, .85, 1],
                                        colors: [
                                          SitePalette.of(
                                            context,
                                          ).canvas.withValues(alpha: 0),
                                          SitePalette.of(
                                            context,
                                          ).canvas.withValues(alpha: .94),
                                          SitePalette.of(
                                            context,
                                          ).canvas.withValues(alpha: .94),
                                          SitePalette.of(
                                            context,
                                          ).canvas.withValues(alpha: 0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            for (var i = 0; i < points.length; i++)
                              Positioned(
                                left: points[i].$2.dx - 22,
                                top: points[i].$2.dy - 22,
                                child: IgnorePointer(
                                  ignoring: !active,
                                  child: ExcludeSemantics(
                                    excluding: !active,
                                    child: Opacity(
                                      opacity: reveal,
                                      child: _StoryMapPin(
                                        number: i + 1,
                                        story: points[i].$1,
                                        onTap: () =>
                                            widget.onExplore(points[i].$1),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  // The compass crosses the fold instead of being clipped by the hero.
                  Positioned(
                    left: compassCenter.dx - compassSize / 2,
                    top: compassCenter.dy - compassSize / 2,
                    width: compassSize,
                    height: compassSize,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: CustomPaint(
                          painter: CompassPainter(
                            angle: angle,
                            dark: SitePalette.of(context).dark,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      KeyedSubtree(key: _heroKey, child: widget.hero),
                      SizedBox(
                        height: sectionHeight,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: margin,
                              right: narrow ? margin : 0,
                              top: narrow ? 90 : 145,
                            ),
                            child: SizedBox(
                              width: narrow
                                  ? width - 48
                                  : math.min(440, width * .36),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SectionEyebrow('El mapa vivo'),
                                  SizedBox(height: 18),
                                  AnimatedDefaultTextStyle(
                                    duration: Duration(milliseconds: 350),
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium!
                                        .copyWith(
                                          fontSize: narrow ? 35 : 46,
                                          height: 1.08,
                                          color: active
                                              ? SitePalette.of(context).green
                                              : SitePalette.of(context).ink,
                                        ),
                                    child: Text(
                                      'Cada punto guarda\nalgo para contar.',
                                      key: ValueKey('cartography-heading'),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    'Recorré La Plata por barrio, época o curiosidad. Historias documentadas y memorias de quienes la habitan.',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: SitePalette.of(context).muted,
                                          height: 1.55,
                                        ),
                                  ),
                                  SizedBox(height: 20),
                                  TextButton(
                                    onPressed: () => widget.onExplore(null),
                                    style: TextButton.styleFrom(
                                      foregroundColor: SitePalette.of(
                                        context,
                                      ).green,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Abrir el mapa',
                                            style: TextStyle(
                                              fontFamily: 'Lora',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 22,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: SitePalette.of(
                                                context,
                                              ).green,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Icon(Icons.chevron_right_rounded),
                                      ],
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
                  Positioned(
                    right: 16,
                    bottom: 10,
                    child: Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(
                        fontSize: 10,
                        color: SitePalette.of(context).muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ColoredBox(
          color: SitePalette.of(context).canvas,
          child: scroll == null
              ? scene()
              : AnimatedBuilder(animation: scroll, builder: (_, _) => scene()),
        );
      },
    );
  }
}

class _StoryMapPin extends StatefulWidget {
  const _StoryMapPin({
    required this.number,
    required this.story,
    required this.onTap,
  });
  final int number;
  final CityStory story;
  final VoidCallback onTap;
  @override
  State<_StoryMapPin> createState() => _StoryMapPinState();
}

class _StoryMapPinState extends State<_StoryMapPin> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.story.title,
    child: Semantics(
      container: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: SitePalette.of(context).canvas.withValues(alpha: 0),
          child: InkWell(
            onTap: widget.onTap,
            onFocusChange: (value) => setState(() => _hover = value),
            borderRadius: BorderRadius.circular(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _hover
                        ? SitePalette.of(context).green
                        : SitePalette.of(context).canvas,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SitePalette.of(context).green,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(color: Color(0x20566C32), blurRadius: 12),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.number.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: _hover
                          ? SitePalette.of(context).canvas
                          : SitePalette.of(context).green,
                    ),
                  ),
                ),
                SizedBox(height: 5),
                Container(
                  width: 128,
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  color: SitePalette.of(context).canvas.withValues(alpha: .90),
                  child: Text(
                    widget.story.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 12,
                      height: 1.2,
                      color: SitePalette.of(context).green,
                    ),
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

class _MapGeometry {
  _MapGeometry(this.roads, this.avenues, this.parks);
  final Path roads, avenues, parks;
  static _MapGeometry decode(String source) {
    final raw = jsonDecode(source) as Map<String, dynamic>;
    final roads = Path(), avenues = Path(), parks = Path();
    void append(Path path, List<dynamic> points, {bool closed = false}) {
      if (points.isEmpty) return;
      path.moveTo(
        (points.first[0] as num).toDouble(),
        (points.first[1] as num).toDouble(),
      );
      for (final p in points.skip(1)) {
        path.lineTo((p[0] as num).toDouble(), (p[1] as num).toDouble());
      }
      if (closed) path.close();
    }

    for (final road in raw['roads']) {
      append(
        ['primary', 'secondary', 'tertiary'].contains(road[0])
            ? avenues
            : roads,
        road[1],
      );
    }
    for (final park in raw['parks']) {
      append(parks, park['points'], closed: true);
    }
    return _MapGeometry(roads, avenues, parks);
  }
}

class _CartographyPainter extends CustomPainter {
  _CartographyPainter(
    this.dark,
    this.geometry,
    this.projection,
    this.reveal,
    this.points,
  );
  final bool dark;
  final _MapGeometry? geometry;
  final HomeMapProjection projection;
  final double reveal;
  final List<Offset> points;
  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    if (g == null) return;
    canvas.save();
    final origin = projection.source(Offset.zero);
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(projection.scale);
    canvas.drawPath(
      g.parks,
      Paint()
        ..color = Color.lerp(
          (dark ? Color(0xFF243B36) : Color(0xFFE8DFC4)),
          (dark ? Color(0xFF647C4A) : Color(0xFFADC276)),
          reveal,
        )!,
    );
    canvas.drawPath(
      g.roads,
      Paint()
        ..color = (dark ? Color(0xFF33464D) : Color(0xFFDED3B5))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawPath(
      g.avenues,
      Paint()
        ..color = (dark ? Color(0xFF576456) : Color(0xFFC8B992))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.restore();
    if (points.length < 2 || reveal == 0) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      path.cubicTo(
        a.dx + 45,
        a.dy + (b.dy - a.dy) * .35,
        b.dx - 45,
        b.dy - (b.dy - a.dy) * .35,
        b.dx,
        b.dy,
      );
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * reveal),
        Paint()
          ..color = (dark ? Color(0xFFB9C795) : tiloInk).withValues(
            alpha: .70 * reveal,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CartographyPainter old) =>
      old.dark != dark ||
      old.geometry != geometry ||
      old.reveal != reveal ||
      old.projection.size != projection.size ||
      old.projection.sectionTop != projection.sectionTop ||
      !_samePoints(old.points);
  bool _samePoints(List<Offset> other) =>
      other.length == points.length &&
      List.generate(
        points.length,
        (i) => other[i] == points[i],
      ).every((v) => v);
}
