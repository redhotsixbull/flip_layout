import 'package:flutter/physics.dart';

/// A **velocity-preserving** spring for `LayoutMotion`/`MotionGroup` slides.
///
/// Unlike [SpringCurve] — which samples a spring onto a fixed `t ∈ [0, 1]` and
/// so only gives a spring *look* — a [MotionSpring] drives the slide with a live
/// [SpringSimulation] on an unbounded controller. There is **no fixed
/// duration**: the motion runs until the physics settle, and an interruption
/// (a re-order mid-slide) carries the element's current **velocity** into the
/// new spring, so momentum is preserved instead of restarting from rest.
///
/// ```dart
/// MotionGroup(
///   spring: const MotionSpring(stiffness: 220, damping: 22),
///   children: [...],
///   builder: (context, children) => Wrap(children: children),
/// )
/// ```
///
/// Lower [damping] overshoots and bounces more; higher [damping] settles without
/// overshoot. When a `spring` is supplied it takes precedence over `duration`
/// for the position slide (the slide is physics-timed, not duration-timed).
class MotionSpring {
  const MotionSpring({
    this.mass = 1.0,
    this.stiffness = 180.0,
    this.damping = 20.0,
  })  : assert(mass > 0),
        assert(stiffness > 0),
        assert(damping >= 0);

  final double mass;
  final double stiffness;
  final double damping;

  /// A gentle, near-critically-damped preset (minimal overshoot).
  static const MotionSpring gentle =
      MotionSpring(stiffness: 170, damping: 24);

  /// A bouncy, underdamped preset (visible overshoot-and-settle).
  static const MotionSpring bouncy =
      MotionSpring(stiffness: 260, damping: 12);

  SpringDescription get description =>
      SpringDescription(mass: mass, stiffness: stiffness, damping: damping);

  @override
  bool operator ==(Object other) =>
      other is MotionSpring &&
      other.mass == mass &&
      other.stiffness == stiffness &&
      other.damping == damping;

  @override
  int get hashCode => Object.hash(mass, stiffness, damping);
}
