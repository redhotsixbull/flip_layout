import 'package:flutter/widgets.dart';

import 'layout_motion.dart';

/// Convenience widget that wraps each child of a layout container in a
/// [LayoutMotion]. Use this when you want a Column/Row/Wrap whose children
/// animate smoothly on reorder or filter.
///
/// The `wrap` helper preserves each child's key onto the [LayoutMotion] so the
/// framework can match widgets across reorders. **Every wrapped child must
/// carry a key** (e.g. `ValueKey`), otherwise reorder identity — and thus the
/// animation — is lost. This is asserted in debug mode.
///
/// ```dart
/// AnimatedLayout(
///   duration: Duration(milliseconds: 250),
///   builder: (context, wrap) => Wrap(
///     children: items.map((i) => wrap(Chip(key: ValueKey(i), ...))).toList(),
///   ),
/// );
/// ```
class AnimatedLayout extends StatelessWidget {
  const AnimatedLayout({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.animateSize = false,
  });

  final Widget Function(BuildContext context, Widget Function(Widget child) wrap)
      builder;
  final Duration duration;
  final Curve curve;
  final bool animateSize;

  @override
  Widget build(BuildContext context) {
    return builder(
      context,
      (Widget child) {
        assert(
          child.key != null,
          'AnimatedLayout children must have a key so reorders can be matched. '
          'Give each child a ValueKey (or similar).',
        );
        return LayoutMotion(
          key: child.key,
          duration: duration,
          curve: curve,
          animateSize: animateSize,
          child: child,
        );
      },
    );
  }
}
