import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'motion_config.dart';
import 'motion_spring.dart';

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
/// The slide can be timed two ways:
///   * **Curve** (default): a fixed [duration] eased by [curve]. Interruptions
///     are position-continuous but restart the ease from rest.
///   * **Spring** ([spring]): a live [SpringSimulation] on an unbounded
///     controller — no fixed duration, and an interruption carries the current
///     **velocity** into the new spring, preserving momentum.
///
/// Wrap any widget you want to be layout-aware:
/// ```dart
/// LayoutMotion(child: Card(...))
/// ```
class LayoutMotion extends StatefulWidget {
  const LayoutMotion({
    super.key,
    required this.child,
    this.duration,
    this.curve,
    this.spring,
    this.animateSize = false,
    this.onEnd,
  });

  final Widget child;

  /// Slide duration for the curve path. When null, inherits from an ancestor
  /// [MotionConfig] (else 300ms). Collapses to zero when motion is reduced.
  /// Ignored when a [spring] is in effect (springs are physics-timed).
  final Duration? duration;

  /// Slide curve. When null, inherits from [MotionConfig] (else easeOutCubic).
  final Curve? curve;

  /// Velocity-preserving spring for the position slide. When non-null (own arg
  /// or inherited from [MotionConfig]), the slide is driven by live physics and
  /// interruptions carry momentum, instead of the fixed-[duration] curve path.
  final MotionSpring? spring;

  /// If true, animate `Size` changes in addition to position. Off by default
  /// because size interpolation via `Transform.scale` distorts child rendering
  /// (text/borders stretch rather than re-layout). Treat it as a visual-only
  /// effect for uniform boxes. Size always uses the [curve]/[duration] path
  /// (only position springs).
  final bool animateSize;

  /// Called once each time a slide/scale animation finishes.
  final VoidCallback? onEnd;

  @override
  State<LayoutMotion> createState() => _LayoutMotionState();
}

class _LayoutMotionState extends State<LayoutMotion>
    with TickerProviderStateMixin {
  final _key = GlobalKey();

  /// Drives the curve-path slide (and the size scale in both paths).
  late final AnimationController _controller;

  /// Per-axis unbounded controllers for the spring path. Created lazily the
  /// first time a spring slide runs, so the common curve path pays nothing.
  AnimationController? _springX;
  AnimationController? _springY;

  Rect? _previousBounds;
  Offset _fromOffset = Offset.zero;
  double _fromScaleX = 1.0;
  double _fromScaleY = 1.0;
  Curve _curve = Curves.easeOutCubic;
  MotionSpring? _spring;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Settle back to identity so the resting transform is exactly zero.
      _fromOffset = Offset.zero;
      _fromScaleX = 1.0;
      _fromScaleY = 1.0;
      // In spring mode the spring controllers own onEnd (the curve controller
      // here only drives the size scale); avoid firing it twice.
      if (_spring == null) widget.onEnd?.call();
    }
  }

  void _onSpringStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed &&
        status != AnimationStatus.dismissed) {
      return;
    }
    final xDone = !(_springX?.isAnimating ?? false);
    final yDone = !(_springY?.isAnimating ?? false);
    if (xDone && yDone) {
      // Snap the resting offset to exactly zero.
      _springX?.value = 0.0;
      _springY?.value = 0.0;
      widget.onEnd?.call();
    }
  }

  void _ensureSpringControllers() {
    _springX ??= AnimationController.unbounded(vsync: this)
      ..addStatusListener(_onSpringStatus);
    _springY ??= AnimationController.unbounded(vsync: this)
      ..addStatusListener(_onSpringStatus);
  }

  // Duration/curve/spring/reduce are resolved from context in [build].

  /// The current inverse translation to paint the child at.
  Offset get _translate {
    if (_spring != null && _springX != null && _springY != null) {
      return Offset(_springX!.value, _springY!.value);
    }
    final t = _curve.transform(_controller.value);
    return Offset.lerp(_fromOffset, Offset.zero, t)!;
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

      if (_reduce) {
        // Reduced motion: jump to the new position with no slide.
        _fromOffset = Offset.zero;
        _fromScaleX = 1.0;
        _fromScaleY = 1.0;
        _controller.value = 1.0;
        _springX?..stop()..value = 0.0;
        _springY?..stop()..value = 0.0;
        return;
      }

      final delta = prev.topLeft - current.topLeft;

      if (widget.animateSize) {
        _fromScaleX = prev.width / current.width;
        _fromScaleY = prev.height / current.height;
      } else {
        _fromScaleX = 1.0;
        _fromScaleY = 1.0;
      }

      if (_spring != null) {
        _startSpring(delta);
        // The size scale (if any) still rides the curve controller.
        if (widget.animateSize) _controller.forward(from: 0.0);
      } else {
        // Interruptible: if a slide is already in flight, start the new one from
        // the element's *current on-screen* offset instead of snapping to 0, so
        // a reorder-during-reorder stays position-continuous (no visible jump).
        final currentTranslate = _controller.isAnimating
            ? Offset.lerp(
                _fromOffset, Offset.zero, _curve.transform(_controller.value))!
            : Offset.zero;
        _fromOffset = delta + currentTranslate;
        _controller.forward(from: 0.0);
      }
    });
  }

  /// Starts (or re-targets) the per-axis spring slide, carrying the current
  /// velocity so an interruption keeps momentum.
  void _startSpring(Offset delta) {
    _ensureSpringControllers();
    final desc = _spring!.description;
    for (final (ctrl, deltaComponent) in [
      (_springX!, delta.dx),
      (_springY!, delta.dy),
    ]) {
      // Current on-screen offset for this axis, plus this frame's layout jump,
      // is where the spring must start; it settles back to 0. Velocity is
      // carried from the in-flight simulation (0 if at rest).
      final start = ctrl.value + deltaComponent;
      final velocity = ctrl.isAnimating ? ctrl.velocity : 0.0;
      ctrl.animateWith(SpringSimulation(desc, start, 0.0, velocity));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Resolve duration/curve/spring/reduce from the nearest MotionConfig.
    _reduce = MotionConfig.reduceMotionOf(context);
    _curve = MotionConfig.curveOf(context, widget.curve);
    _spring = MotionConfig.springOf(context, widget.spring);
    _controller.duration = MotionConfig.durationOf(context, widget.duration);
    // Create the spring controllers eagerly once a spring is in effect, so the
    // AnimatedBuilder below subscribes to them (a spring started later in a
    // post-frame callback would otherwise tick without repainting).
    if (_spring != null) _ensureSpringControllers();

    _scheduleMeasurement();

    final drivers = <Listenable>[
      _controller,
      if (_springX != null) _springX!,
      if (_springY != null) _springY!,
    ];

    // The GlobalKey lives on a MetaData proxy that sits ABOVE the Transform, so
    // measuring it yields the untransformed layout position.
    return MetaData(
      key: _key,
      child: AnimatedBuilder(
        animation: Listenable.merge(drivers),
        builder: (context, child) {
          final translate = _translate;
          if (!widget.animateSize) {
            return Transform.translate(offset: translate, child: child);
          }
          final t = _curve.transform(_controller.value);
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
    _springX?.dispose();
    _springY?.dispose();
    super.dispose();
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
