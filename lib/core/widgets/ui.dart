import '../theme/site_palette.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'dardito_details.dart';

class SectionEyebrow extends StatelessWidget {
  const SectionEyebrow(this.text, {super.key, this.light = false});
  final String text;
  final bool light;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DarditoDetail(size: 23),
      SizedBox(width: 10),
      Flexible(
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w900,
            color: light
                ? SitePalette.of(context).cream
                : SitePalette.of(context).ink,
          ),
        ),
      ),
    ],
  );
}

class TrustBadge extends StatelessWidget {
  const TrustBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

class ProjectMark extends StatelessWidget {
  const ProjectMark({super.key, this.light = false, this.compact = false});
  final bool light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 42.0 : 62.0;
    return Semantics(
      image: true,
      label: 'El Mapa de las Historias de La Plata',
      child: Container(
        height: height,
        width: height * 3.06,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 8,
          vertical: compact ? 3 : 5,
        ),
        child: ColorFiltered(
          colorFilter: SitePalette.of(context).dark
              ? ColorFilter.mode(SitePalette.of(context).ink, BlendMode.srcIn)
              : const ColorFilter.matrix([
                  1,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
          child: ColorFiltered(
            // Remove the white JPEG ground at render time, preserving the asset.
            colorFilter: const ColorFilter.matrix([
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              -.2126,
              -.7152,
              -.0722,
              0,
              255,
            ]),
            child: Image.asset(
              'assets/brand/mhdlp_logo_horizontal.jpg',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}

class MaxWidth extends StatelessWidget {
  const MaxWidth({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 1240),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.trailing,
  });
  final String eyebrow;
  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionEyebrow(eyebrow),
            SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.displayMedium),
            if (description != null) ...[
              SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 650),
                child: Text(
                  description!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: SitePalette.of(context).muted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.distance = 7,
    this.scale = 1.012,
  });

  final Widget child;
  final double distance;
  final double scale;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onFocusChange: (value) => setState(() => _focused = value),
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: (_hovered || _focused) ? widget.scale : 1,
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: Offset(
            0,
            (_hovered || _focused) ? -widget.distance / 100 : 0,
          ),
          duration: Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 220),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: (_hovered || _focused)
                  ? [
                      BoxShadow(
                        color: SitePalette.of(
                          context,
                        ).ink.withValues(alpha: .13),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              children: [
                widget.child,
                Positioned(
                  top: 6,
                  right: 16,
                  child: AnimatedOpacity(
                    opacity: (_hovered || _focused) ? 1 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : Duration(milliseconds: 180),
                    child: DarditoDetail(ribbon: true, size: 12),
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

class Entrance extends StatelessWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.distance = 24,
    this.startScale = 1,
  });
  final Widget child;
  final Duration delay;
  final double distance;
  final double startScale;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 650 + delay.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final progress = delay.inMilliseconds == 0
            ? value
            : ((value * (650 + delay.inMilliseconds) - delay.inMilliseconds) /
                      650)
                  .clamp(0.0, 1.0);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, distance * (1 - progress)),
            child: Transform.scale(
              scale: startScale + ((1 - startScale) * progress),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class ScrollEntrance extends StatefulWidget {
  const ScrollEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.distance = .07,
    this.startScale = .98,
  });

  final Widget child;
  final Duration delay;
  final double distance;
  final double startScale;

  @override
  State<ScrollEntrance> createState() => _ScrollEntranceState();
}

class _ScrollEntranceState extends State<ScrollEntrance> {
  ScrollPosition? _position;
  Timer? _delayTimer;
  bool _visible = false;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (_position != nextPosition) {
      _position?.removeListener(_checkVisibility);
      _position = nextPosition?..addListener(_checkVisibility);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  void _checkVisibility() {
    if (!mounted || _visible || _scheduled) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    if (top < viewportHeight * .92 && bottom > 0) {
      _scheduled = true;
      _delayTimer = Timer(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_checkVisibility);
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : Offset(0, widget.distance),
        duration: Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: _visible ? 1 : widget.startScale,
          duration: Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}
