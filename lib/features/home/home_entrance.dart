import 'package:flutter/material.dart';

/// Plays once when the content enters the viewport; scrolling back never restarts it.
class HomeEntrance extends StatefulWidget {
  const HomeEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 650),
    this.builder,
  });
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Widget Function(BuildContext, double, Widget)? builder;
  @override
  State<HomeEntrance> createState() => _HomeEntranceState();
}

class _HomeEntranceState extends State<HomeEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );
  ScrollPosition? _position;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (_position != position) {
      _position?.removeListener(_checkVisibility);
      _position = position;
      _position?.addListener(_checkVisibility);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _controller.value = 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  void _checkVisibility() {
    if (!mounted || _started) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.sizeOf(context).height - 32 &&
        top + box.size.height > 0) {
      _started = true;
      _controller.forward();
      _position?.removeListener(_checkVisibility);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_checkVisibility);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final start =
          widget.delay.inMilliseconds /
          (widget.delay + widget.duration).inMilliseconds;
      final t = ((_controller.value - start) / (1 - start)).clamp(0.0, 1.0);
      if (widget.builder != null) return widget.builder!(context, t, child!);
      final eased = Curves.easeOutCubic.transform(t);
      return Opacity(
        opacity: eased,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - eased)),
          child: child,
        ),
      );
    },
  );
}

class DarditoAnimatedName extends StatelessWidget {
  const DarditoAnimatedName({super.key, required this.style});
  final TextStyle style;
  @override
  Widget build(BuildContext context) => HomeEntrance(
    delay: const Duration(milliseconds: 550),
    duration: const Duration(milliseconds: 900),
    child: Text('Dardito', style: style),
    builder: (context, t, child) => Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < 'Dardito'.length; i++)
            TextSpan(
              text: 'Dardito'[i],
              style: style.copyWith(
                color: (style.color ?? Colors.black).withValues(
                  alpha: (t * 8 - i).clamp(0.0, 1.0),
                ),
              ),
            ),
        ],
      ),
      style: style,
      semanticsLabel: 'Dardito',
    ),
  );
}
