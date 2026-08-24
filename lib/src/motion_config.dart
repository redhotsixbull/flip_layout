import 'package:flutter/widgets.dart';

import 'motion_spring.dart';

/// Subtree-wide motion defaults. Wrap part of your app in a [MotionConfig] and
/// every [LayoutMotion]/[MotionGroup] below inherits its `duration`/`curve`/
/// `stagger`, and honours its "reduce motion" setting — set it once instead of
/// threading the same values through every widget (Framer Motion's
/// `MotionConfig`).
///
/// Resolution precedence for any value: **the widget's own argument** → the
/// nearest [MotionConfig] → a built-in default. When motion is reduced,
/// animation durations collapse to zero so changes apply instantly.
///
/// ```dart
/// MotionConfig(
///   duration: Duration(milliseconds: 220),
///   curve: Curves.easeOutBack,
///   child: MyPage(), // every MotionGroup/LayoutMotion inside uses these
/// )
/// ```
class MotionConfig extends InheritedWidget {
  const MotionConfig({
    super.key,
    this.duration,
    this.curve,
    this.stagger,
    this.spring,
    this.reduceMotion,
    required super.child,
  });

  final Duration? duration;
  final Curve? curve;
  final Duration? stagger;

  /// Default velocity-preserving [MotionSpring] for position slides. When set,
  /// it drives `LayoutMotion`/`MotionGroup` FLIP slides with live physics (and
  /// takes precedence over `duration`/`curve` for the slide). Widgets can still
  /// override it with their own `spring:` argument.
  final MotionSpring? spring;

  /// Skip animations and apply changes instantly. When null, falls back to the
  /// platform accessibility setting via `MediaQuery.disableAnimations`.
  final bool? reduceMotion;

  static const _defaultDuration = Duration(milliseconds: 300);
  static const _defaultCurve = Curves.easeOutCubic;

  static MotionConfig? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MotionConfig>();

  /// Whether motion should be reduced for [context] (config override, else the
  /// platform "reduce motion" accessibility setting).
  static bool reduceMotionOf(BuildContext context) {
    final cfg = maybeOf(context);
    return cfg?.reduceMotion ??
        MediaQuery.maybeOf(context)?.disableAnimations ??
        false;
  }

  /// Effective duration: `own` → config → default, or zero when reduced.
  static Duration durationOf(BuildContext context, Duration? own) {
    if (reduceMotionOf(context)) return Duration.zero;
    return own ?? maybeOf(context)?.duration ?? _defaultDuration;
  }

  /// Effective curve: `own` → config → default.
  static Curve curveOf(BuildContext context, Curve? own) =>
      own ?? maybeOf(context)?.curve ?? _defaultCurve;

  /// Effective stagger: `own` → config → zero, or zero when reduced.
  static Duration staggerOf(BuildContext context, Duration? own) {
    if (reduceMotionOf(context)) return Duration.zero;
    return own ?? maybeOf(context)?.stagger ?? Duration.zero;
  }

  /// Effective spring: `own` → config → null (no spring; use the curve path).
  static MotionSpring? springOf(BuildContext context, MotionSpring? own) =>
      own ?? maybeOf(context)?.spring;

  @override
  bool updateShouldNotify(MotionConfig old) =>
      duration != old.duration ||
      curve != old.curve ||
      stagger != old.stagger ||
      spring != old.spring ||
      reduceMotion != old.reduceMotion;
}
