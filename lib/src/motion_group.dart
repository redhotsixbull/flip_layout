import 'package:flutter/widgets.dart';

import 'layout_motion.dart';

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
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.stagger = Duration.zero,
    this.animateInitial = true,
    this.transitionBuilder = defaultTransition,
  });

  /// The desired children. Each must have a unique [Key].
  final List<Widget> children;

  /// Arranges the (animation-wrapped) children into a layout.
  final Widget Function(BuildContext context, List<Widget> children) builder;

  final Duration duration;
  final Curve curve;

  /// Delay applied between successive children entering in the same batch, for
  /// a staggered reveal (Framer Motion's `staggerChildren`). Zero = together.
  final Duration stagger;

  /// Whether the very first set of children animates in. Set false to have the
  /// initial content appear instantly (like Framer Motion's `initial={false}`).
  final bool animateInitial;

  /// Builds the enter/exit transition. [animation] runs 0→1 on enter and 1→0 on
  /// exit. Defaults to a combined fade + scale.
  final Widget Function(
      BuildContext context, Animation<double> animation, Widget child) transitionBuilder;

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
}

class _MotionGroupState extends State<MotionGroup> with TickerProviderStateMixin {
  final List<_Slot> _slots = [];

  @override
  void initState() {
    super.initState();
    _sync(initial: true);
  }

  @override
  void didUpdateWidget(covariant MotionGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(initial: false);
  }

  void _sync({required bool initial}) {
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
        final controller =
            AnimationController(vsync: this, duration: widget.duration);
        final s = _Slot(
          key,
          child,
          controller,
          CurvedAnimation(parent: controller, curve: widget.curve),
        );
        controller.addStatusListener((status) {
          if (status == AnimationStatus.dismissed && s.exiting) _removeSlot(s);
        });
        newBatch.add(s);
        present.add(s);
      } else {
        slot.widget = child;
        if (slot.exiting) {
          slot.exiting = false;
          slot.controller.forward(); // revived before it finished leaving
        }
        present.add(slot);
      }
    }

    final presentKeys = {for (final s in present) s.key};

    // Anything that was here but isn't in `children` now → animate out.
    final exiting = <_Slot>[];
    for (final s in oldSlots) {
      if (presentKeys.contains(s.key)) continue;
      if (!s.exiting) {
        s.exiting = true;
        s.controller.reverse();
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
  }

  void _startEnterAnimations(List<_Slot> batch, {required bool initial}) {
    for (var i = 0; i < batch.length; i++) {
      final s = batch[i];
      if (initial && !widget.animateInitial) {
        s.controller.value = 1.0;
        continue;
      }
      if (widget.stagger == Duration.zero) {
        s.controller.forward();
      } else {
        Future<void>.delayed(widget.stagger * i, () {
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
    final children = <Widget>[
      for (final s in _slots)
        LayoutMotion(
          key: s.key,
          duration: widget.duration,
          curve: widget.curve,
          child: widget.transitionBuilder(context, s.animation, s.widget),
        ),
    ];
    return widget.builder(context, children);
  }
}
