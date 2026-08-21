import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'layout_motion.dart';
import 'motion_config.dart';
import 'motion_spring.dart';

/// Arranges [children] through [builder] (a `Wrap`, `Column`, `GridView`, …)
/// and declaratively animates the collection as it changes:
///
///   * **Enter** — children added since the last build fade/scale in.
///   * **Exit** — children removed from [children] are kept mounted and animated
///     out (fade/scale) before being removed (an `AnimatePresence` equivalent).
///   * **Layout** — surviving children slide to their new positions via FLIP
///     when siblings enter/leave or the order changes.
///
/// This fills the gap Flutter's built-ins leave: `AnimatedList` only does a
/// single `ListView` and is imperative; `AnimatedSize`/`ExpansionTile` only do
/// size. `MotionGroup` is declarative (just change [children]) and works with
/// **any** layout — including `Wrap` and `GridView`.
///
/// Every child **must** carry a unique [Key] so it can be tracked across builds.
///
/// ```dart
/// MotionGroup(
///   children: [
///     for (final tag in visibleTags) Chip(key: ValueKey(tag), label: Text(tag)),
///   ],
///   builder: (context, children) => Wrap(spacing: 8, children: children),
/// )
/// ```
class MotionGroup extends StatefulWidget {
  const MotionGroup({
    super.key,
    required this.children,
    required this.builder,
    this.duration,
    this.curve,
    this.spring,
    this.stagger,
    this.exitStagger,
    this.animateInitial = true,
    this.transitionBuilder = defaultTransition,
    this.exitTransitionBuilder,
    this.onEnter,
    this.onExitComplete,
  });

  /// The desired children. Each must have a unique [Key].
  final List<Widget> children;

  /// Arranges the (animation-wrapped) children into a layout.
  final Widget Function(BuildContext context, List<Widget> children) builder;

  /// Enter/exit + slide duration. When null, inherits from an ancestor
  /// [MotionConfig] (else 300ms); zero when motion is reduced.
  final Duration? duration;

  /// Curve for enter/exit + slide. When null, inherits from [MotionConfig].
  final Curve? curve;

  /// Velocity-preserving [MotionSpring] for the **layout (FLIP) slide** of
  /// surviving children. When set (own arg or via [MotionConfig]), reorders keep
  /// momentum through interruptions. Enter/exit transitions still use
  /// [duration]/[curve]. When null, the slide uses the curve path.
  final MotionSpring? spring;

  /// Delay applied between successive children entering in the same batch, for
  /// a staggered reveal (Framer Motion's `staggerChildren`). When null, inherits
  /// from [MotionConfig] (else zero = together).
  final Duration? stagger;

  /// Delay applied between successive children *leaving* in the same removal
  /// batch, so a group of children exit one-after-another rather than all at
  /// once. Each leaving child stays fully visible until its turn. Zero (the
  /// default) exits them together. Collapses to zero when motion is reduced.
  final Duration? exitStagger;

  /// Called once when a child (identified by its [Key]) has finished entering —
  /// its enter transition reached the end. Not called for a first batch placed
  /// instantly via `animateInitial: false` (no transition runs). Framer Motion's
  /// per-child `onAnimationComplete`.
  final void Function(Key key)? onEnter;

  /// Called once when a leaving child has finished its exit transition and has
  /// been removed from the tree (Framer Motion's `onExitComplete`, per child).
  final void Function(Key key)? onExitComplete;

  /// Whether the very first set of children animates in. Set false to have the
  /// initial content appear instantly (like Framer Motion's `initial={false}`).
  final bool animateInitial;

  /// Builds the **enter** transition (and the exit transition too, unless
  /// [exitTransitionBuilder] is given). [animation] runs 0→1. Defaults to a
  /// combined fade + scale.
  final Widget Function(
      BuildContext context, Animation<double> animation, Widget child) transitionBuilder;

  /// Optional separate **exit** transition, so entering and leaving can differ
  /// (e.g. slide up on enter, shrink on exit). [animation] runs 1→0 while
  /// leaving. When null, [transitionBuilder] is used for exits too.
  final Widget Function(
      BuildContext context, Animation<double> animation, Widget child)? exitTransitionBuilder;

  /// In debug builds, `MotionGroup` prints a one-time warning when its child
  /// count exceeds this threshold, because it manages **all** children at once
  /// (and keeps exiting ones mounted) with a FLIP measurement per child — there
  /// is no virtualisation. Large, scrolling collections should use a windowed
  /// list (`AnimatedList` / `SliverAnimatedList`) instead. Set to a larger value
  /// (or `null` to silence) if you have profiled your case and accept the cost.
  static int? debugChildCountWarningThreshold = 150;

  static Widget defaultTransition(
      BuildContext context, Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
        child: child,
      ),
    );
  }

  @override
  State<MotionGroup> createState() => _MotionGroupState();
}

class _Slot {
  _Slot(this.key, this.widget, this.controller, this.animation);
  final Key key;
  Widget widget;
  final AnimationController controller;
  final Animation<double> animation;
  bool exiting = false;

  /// Set when a real enter animation is started, so `onEnter` fires on its
  /// completion but NOT when a child is placed instantly (value set to 1).
  bool notifyEnter = false;
}

class _MotionGroupState extends State<MotionGroup> with TickerProviderStateMixin {
  final List<_Slot> _slots = [];
  MotionConfig? _config;
  bool _reduce = false;

  Duration get _dur => _reduce
      ? Duration.zero
      : (widget.duration ?? _config?.duration ?? const Duration(milliseconds: 300));
  Curve get _curve => widget.curve ?? _config?.curve ?? Curves.easeOutCubic;
  MotionSpring? get _spring => widget.spring ?? _config?.spring;
  Duration get _stag =>
      _reduce ? Duration.zero : (widget.stagger ?? _config?.stagger ?? Duration.zero);
  Duration get _exitStag =>
      _reduce ? Duration.zero : (widget.exitStagger ?? Duration.zero);

  @override
  void initState() {
    super.initState();
    _sync(initial: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _config = MotionConfig.maybeOf(context);
    _reduce = _config?.reduceMotion ??
        MediaQuery.maybeOf(context)?.disableAnimations ??
        false;
    for (final s in _slots) {
      s.controller.duration = _dur;
    }
  }

  @override
  void didUpdateWidget(covariant MotionGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(initial: false);
  }

  bool _warnedLargeCount = false;

  void _maybeWarnLargeCount() {
    if (!kDebugMode || _warnedLargeCount) return;
    final threshold = MotionGroup.debugChildCountWarningThreshold;
    if (threshold == null || widget.children.length <= threshold) return;
    _warnedLargeCount = true;
    debugPrint(
      'MotionGroup: ${widget.children.length} children exceeds '
      '$threshold. MotionGroup manages every child at once (no '
      'virtualisation) and keeps exiting ones mounted, so large scrolling '
      'collections can be janky. Consider AnimatedList / SliverAnimatedList '
      'for big lists, or raise MotionGroup.debugChildCountWarningThreshold to '
      'silence this once profiled.',
    );
  }

  void _sync({required bool initial}) {
    _maybeWarnLargeCount();
    final existing = {for (final s in _slots) s.key: s};
    final oldSlots = List<_Slot>.of(_slots);
    final oldIndex = {for (var i = 0; i < oldSlots.length; i++) oldSlots[i].key: i};

    final newBatch = <_Slot>[];
    final present = <_Slot>[];
    for (final child in widget.children) {
      final key = child.key;
      assert(key != null, 'MotionGroup children must each have a unique Key.');
      if (key == null) continue;
      final slot = existing[key];
      if (slot == null) {
        final controller = AnimationController(vsync: this, duration: _dur);
        final s = _Slot(
          key,
          child,
          controller,
          CurvedAnimation(parent: controller, curve: _curve),
        );
        controller.addStatusListener((status) {
          if (status == AnimationStatus.completed && !s.exiting && s.notifyEnter) {
            s.notifyEnter = false;
            widget.onEnter?.call(s.key);
          } else if (status == AnimationStatus.dismissed && s.exiting) {
            widget.onExitComplete?.call(s.key);
            _removeSlot(s);
          }
        });
        newBatch.add(s);
        present.add(s);
      } else {
        slot.widget = child;
        if (slot.exiting) {
          slot.exiting = false;
          slot.notifyEnter = true;
          slot.controller.forward(); // revived before it finished leaving
        }
        present.add(slot);
      }
    }

    final presentKeys = {for (final s in present) s.key};

    // Anything that was here but isn't in `children` now → animate out. Newly
    // removed slots are collected so their exit can be staggered.
    final exiting = <_Slot>[];
    final newlyExiting = <_Slot>[];
    for (final s in oldSlots) {
      if (presentKeys.contains(s.key)) continue;
      if (!s.exiting) {
        s.exiting = true;
        newlyExiting.add(s);
      }
      exiting.add(s);
    }

    // Rebuild the ordered slot list: present children in their new order, with
    // exiting children re-inserted at (roughly) their previous position so they
    // don't jump to the end while leaving.
    final result = List<_Slot>.of(present);
    exiting.sort((a, b) => (oldIndex[a.key] ?? 0).compareTo(oldIndex[b.key] ?? 0));
    for (final s in exiting) {
      final idx = (oldIndex[s.key] ?? result.length).clamp(0, result.length);
      result.insert(idx, s);
    }

    _slots
      ..clear()
      ..addAll(result);

    _startEnterAnimations(newBatch, initial: initial);
    _startExitAnimations(newlyExiting);
  }

  void _startExitAnimations(List<_Slot> batch) {
    final stagger = _exitStag;
    for (var i = 0; i < batch.length; i++) {
      final s = batch[i];
      final delay = stagger * i;
      if (delay == Duration.zero) {
        s.controller.reverse();
      } else {
        // Each leaving child stays fully visible until its turn, then reverses.
        Future<void>.delayed(delay, () {
          if (mounted &&
              _slots.contains(s) &&
              s.exiting &&
              s.controller.status != AnimationStatus.dismissed) {
            s.controller.reverse();
          }
        });
      }
    }
  }

  void _startEnterAnimations(List<_Slot> batch, {required bool initial}) {
    for (var i = 0; i < batch.length; i++) {
      final s = batch[i];
      if (initial && !widget.animateInitial) {
        // Placed instantly (no transition) — no onEnter for a non-animation.
        s.controller.value = 1.0;
        continue;
      }
      s.notifyEnter = true;
      final delay = _stag * i;
      if (delay == Duration.zero) {
        s.controller.forward();
      } else {
        Future<void>.delayed(delay, () {
          if (mounted && _slots.contains(s) && !s.exiting) s.controller.forward();
        });
      }
    }
  }

  void _removeSlot(_Slot s) {
    if (!mounted) {
      s.controller.dispose();
      return;
    }
    setState(() => _slots.remove(s));
    s.controller.dispose();
  }

  @override
  void dispose() {
    for (final s in _slots) {
      s.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exitBuilder = widget.exitTransitionBuilder ?? widget.transitionBuilder;
    final children = <Widget>[
      for (final s in _slots)
        LayoutMotion(
          key: s.key,
          duration: _dur,
          curve: _curve,
          spring: _spring,
          child: (s.exiting ? exitBuilder : widget.transitionBuilder)(
              context, s.animation, s.widget),
        ),
    ];
    return widget.builder(context, children);
  }
}
