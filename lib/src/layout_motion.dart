import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A widget that smoothly animates when its own position on screen changes
/// due to layout changes in ancestors (reordering, filtering, expansion, ...).
///
/// Implementation follows the FLIP technique:
///   1. Measure the current bounds after each frame.
///   2. On the next frame, if bounds differ from the previous frame, apply an
///      inverse [Transform.translate] equal to the movement delta and animate
///      it to [Offset.zero] over [duration].
///
/// Wrap any widget you want to be layout-aware:
/// ```dart
/// LayoutMotion(child: Card(...))
/// ```
class LayoutMotion extends StatefulWidget {
  const LayoutMotion({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.animateSize = false,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  /// If true, animate `Size` changes in addition to position. Off by default
  /// because size interpolation via `Transform.scale` distorts child rendering.
  final bool animateSize;

  @override
  State<LayoutMotion> createState() => _LayoutMotionState();
}

class _LayoutMotionState extends State<LayoutMotion>
    with SingleTickerProviderStateMixin {
  final _key = GlobalKey();
  late final AnimationController _controller;
  Rect? _previousBounds;
  Offset _fromOffset = Offset.zero;
  double _fromScaleX = 1.0;
  double _fromScaleY = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didUpdateWidget(covariant LayoutMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
  }

  Rect? _measureBounds() {
    final ctx = _key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _scheduleMeasurement() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _measureBounds();
      if (current == null) return;
      final prev = _previousBounds;
      if (prev != null && prev != current) {
        final delta = prev.topLeft - current.topLeft;
        _fromOffset = delta;
        if (widget.animateSize && current.width > 0 && current.height > 0) {
          _fromScaleX = prev.width / current.width;
          _fromScaleY = prev.height / current.height;
        } else {
          _fromScaleX = 1.0;
          _fromScaleY = 1.0;
        }
        _controller.forward(from: 0.0);
      }
      _previousBounds = current;
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasurement();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.isAnimating || _controller.value > 0
            ? widget.curve.transform(_controller.value)
            : 1.0;
        final translate = Offset.lerp(_fromOffset, Offset.zero, t)!;
        if (!widget.animateSize) {
          return Transform.translate(offset: translate, child: child);
        }
        final scaleX = _lerp(_fromScaleX, 1.0, t);
        final scaleY = _lerp(_fromScaleY, 1.0, t);
        return Transform.translate(
          offset: translate,
          child: Transform(
            alignment: Alignment.topLeft,
            transform: Matrix4.identity()..scaleByDouble(scaleX, scaleY, 1.0, 1.0),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: _key, child: widget.child),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

// Matrix4 scale extension not needed — using Matrix4.identity()..scale(x, y).
