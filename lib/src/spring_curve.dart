import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// A [Curve] shaped by a tunable spring, giving a natural overshoot-and-settle
/// motion. Drop it anywhere a curve is accepted — `LayoutMotion`, `MotionGroup`
/// or `MotionConfig`'s `curve:` — for spring-style slides:
///
/// ```dart
/// MotionConfig(
///   curve: SpringCurve(stiffness: 200, damping: 12),
///   child: MyPage(),
/// )
/// ```
///
/// It samples a [SpringSimulation] normalised onto `t ∈ [0, 1]` (the duration
/// still comes from `duration`), so it's a spring *look*, not velocity-
/// preserving physics. Underdamped springs (low `damping`) overshoot past the
/// target and bounce back; higher `damping` settles without overshoot.
class SpringCurve extends Curve {
  SpringCurve({
    double mass = 1.0,
    double stiffness = 180.0,
    double damping = 12.0,
  }) : _sim = SpringSimulation(
          SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
          0.0, // start
          1.0, // end
          0.0, // initial velocity
        ) {
    // Find when the spring has effectively settled, to normalise time to [0,1].
    var t = 0.0;
    const step = 1 / 240;
    while (!_sim.isDone(t) && t < 12.0) {
      t += step;
    }
    _settleTime = t <= 0 ? step : t;
  }

  final SpringSimulation _sim;
  late final double _settleTime;

  @override
  double transformInternal(double t) => _sim.x(t * _settleTime);
}
