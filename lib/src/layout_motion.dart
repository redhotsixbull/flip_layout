import 'package:flutter/rendering.dart';
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
/// Two subtleties make this robust:
///   * The measured [RenderBox] sits *above* the animating [Transform] (via a
///     [MetaData] proxy), so the in-flight transform never contaminates the
///     next measurement — no jitter or oscillation.
///   * Inside a [Scrollable], positions are measured in the scroll *content*
///     space (viewport-relative + scroll offset), so plain scrolling does not
///     look like a layout move and won't trigger a spurious animation.
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
    this.onEnd,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  /// If true, animate `Size` changes in addition to position. Off by default
  /// because size interpolation via `Transform.scale` distorts child rendering
  /// (text/borders stretch rather than re-layout). Treat it as a visual-only
  /// effect for uniform boxes.
  final bool animateSize;

  /// Called once each time a slide/scale animation finishes.
  final VoidCallback? onEnd;

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
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Settle back to identity so the resting transform is exactly zero.
      _fromOffset = Offset.zero;
      _fromScaleX = 1.0;
      _fromScaleY = 1.0;
      widget.onEnd?.call();
    }
  }

  @override
  void didUpdateWidget(covariant LayoutMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
  }

  /// Measures the widget's untransformed bounds. Inside a [Scrollable] the
  /// result is in scroll-content space so scrolling doesn't register as a move.
  Rect? _measureBounds() {
    final ctx = _key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;

    final scrollable = Scrollable.maybeOf(ctx);
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (scrollable != null && viewport != null) {
      final rel = box.localToGlobal(Offset.zero, ancestor: viewport);
      final pos = scrollable.position;
      // viewport-relative position DEcreases as we scroll while pixels
      // INcreases by the same amount → the sum is scroll-invariant.
      final origin = pos.axis == Axis.vertical
          ? Offset(rel.dx, rel.dy + pos.pixels)
          : Offset(rel.dx + pos.pixels, rel.dy);
      return origin & box.size;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _scheduleMeasurement() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _measureBounds();
      if (current == null) return;
      final prev = _previousBounds;
      _previousBounds = current;

      if (prev == null || prev == current) return;
      // Skip degenerate transitions (offstage → onstage, zero-size) that would
      // otherwise produce a large bogus delta.
      if (prev.isEmpty || current.isEmpty) return;

      _fromOffset = prev.topLeft - current.topLeft;
      if (widget.animateSize) {
        _fromScaleX = prev.width / current.width;
        _fromScaleY = prev.height / current.height;
      } else {
        _fromScaleX = 1.0;
        _fromScaleY = 1.0;
      }
      _controller.forward(from: 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasurement();
    // The GlobalKey lives on a MetaData proxy that sits ABOVE the Transform, so
    // measuring it yields the untransformed layout position.
    return MetaData(
      key: _key,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = widget.curve.transform(_controller.value);
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
              transform: Matrix4.identity()
                ..scaleByDouble(scaleX, scaleY, 1.0, 1.0),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
