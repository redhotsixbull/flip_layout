import 'package:flutter/widgets.dart';

import 'layout_motion.dart';

/// Convenience widget that recursively wraps each direct child of a layout
/// container in a [LayoutMotion]. Use this when you want a Column/Row/Wrap
/// whose children animate smoothly on reorder or filter.
///
/// ```dart
/// AnimatedLayout(
///   duration: Duration(milliseconds: 250),
///   builder: (context, wrap) => Wrap(children: items.map(wrap).toList()),
/// );
/// ```
class AnimatedLayout extends StatelessWidget {
  const AnimatedLayout({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
  });

  final Widget Function(BuildContext context, Widget Function(Widget child) wrap)
      builder;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return builder(
      context,
      (Widget child) => LayoutMotion(
        key: child.key,
        duration: duration,
        curve: curve,
        child: child,
      ),
    );
  }
}
