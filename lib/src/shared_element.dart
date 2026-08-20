import 'package:flutter/widgets.dart';

/// Wrap a region in a [MotionSharedScope], then give two widgets the same
/// [MotionSharedId] `id`. When one disappears and the other appears (or the
/// element simply moves to a new place) — **within the same page, no route
/// change** — a copy flies from the old rect to the new one over the scope's
/// `duration`/`curve`.
///
/// This is the "magic move" / shared-layout transition Flutter's [Hero] only
/// does across routes.
///
/// ```dart
/// MotionSharedScope(
///   child: selected == null
///       ? Grid(... MotionSharedId(id: item.id, child: Thumb(item)) ...)
///       : Detail(MotionSharedId(id: selected.id, child: BigImage(selected))),
/// )
/// ```
class MotionSharedScope extends StatefulWidget {
  const MotionSharedScope({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeInOutCubic,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  State<MotionSharedScope> createState() => _MotionSharedScopeState();

  static SharedElementController? _maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SharedScopeInherited>()
        ?.controller;
  }
}

class _MotionSharedScopeState extends State<MotionSharedScope>
    with TickerProviderStateMixin {
  late final SharedElementController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SharedElementController(
      vsync: this,
      overlayOf: () => Overlay.of(context),
      duration: widget.duration,
      curve: widget.curve,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SharedScopeInherited(
      controller: _controller,
      child: widget.child,
    );
  }
}

class _SharedScopeInherited extends InheritedNotifier<SharedElementController> {
  const _SharedScopeInherited({
    required SharedElementController controller,
    required super.child,
  }) : super(notifier: controller);

  SharedElementController get controller => notifier!;
}

typedef _RectGetter = Rect? Function();

class _Registration {
  _Registration(this.token, this.rectOf, this.child);

  /// Identity of the element currently holding this id (its State object). A
  /// flight is only triggered when this *changes* (one widget replaced another),
  /// never when the same element merely moves (scrolling, relayout).
  final Object token;
  _RectGetter rectOf;
  Widget child;
}

/// Tracks active [MotionSharedId]s by id, and flies an overlay copy from an
/// id's previous rect to its new rect whenever it moves. Notifies listeners
/// when the set of in-flight ids changes so the real widgets can hide.
class SharedElementController extends ChangeNotifier {
  SharedElementController({
    required this.vsync,
    required this.overlayOf,
    required this.duration,
    required this.curve,
  });

  final TickerProvider vsync;
  final OverlayState? Function() overlayOf;
  final Duration duration;
  final Curve curve;

  final Map<Object, _Registration> _active = {};
  final Map<Object, Rect> _lastRect = {};
  final Map<Object, Object> _lastHolder = {};
  final Set<Object> _flying = {};
  bool _scheduled = false;

  bool isFlying(Object id) => _flying.contains(id);

  void register(Object id, Object token, Rect? Function() rectOf, Widget child) {
    _active[id] = _Registration(token, rectOf, child);
    _schedule();
  }

  void unregister(Object id, Object token) {
    // Only drop it if the current registration is still this element (a newer
    // holder may already have replaced it during a swap).
    if (identical(_active[id]?.token, token)) _active.remove(id);
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (vsync is State && !(vsync as State).mounted) return;
      _process();
    });
  }

  void _process() {
    for (final entry in _active.entries.toList()) {
      final id = entry.key;
      if (_flying.contains(id)) continue;
      final reg = entry.value;
      final rect = reg.rectOf();
      if (rect == null || rect.isEmpty) continue;

      final lastRect = _lastRect[id];
      final lastHolder = _lastHolder[id];
      // Only fly when a *different* element now holds this id (a swap), and it
      // landed somewhere new. The same element moving (scroll/relayout) is
      // ignored — that's not a shared-element transition.
      final swapped = lastHolder != null && !identical(lastHolder, reg.token);

      _lastRect[id] = rect;
      _lastHolder[id] = reg.token;

      if (swapped && lastRect != null && lastRect != rect) {
        _fly(id, lastRect, rect, reg.child);
      }
    }
  }

  void _fly(Object id, Rect from, Rect to, Widget child) {
    final overlay = overlayOf();
    if (overlay == null) {
      _lastRect[id] = to;
      return;
    }
    _flying.add(id);
    notifyListeners(); // real widget with this id hides itself

    final controller = AnimationController(vsync: vsync, duration: duration);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = curve.transform(controller.value);
          final rect = Rect.lerp(from, to, t)!;
          // Positioned.fromRect gives the child tight rect constraints, so a
          // size-flexible child re-lays-out at each interpolated size (true
          // layout interpolation, not a scale). Give shared children no fixed
          // size for the smoothest result.
          return Positioned.fromRect(rect: rect, child: child);
        },
      ),
    );
    overlay.insert(entry);
    controller.forward().whenCompleteOrCancel(() {
      entry.remove();
      controller.dispose();
      _flying.remove(id);
      if (!_disposed) notifyListeners(); // reveal the real widget
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A widget that participates in shared-element transitions. Two of these with
/// the same [id] under one [MotionSharedScope] animate between each other.
class MotionSharedId extends StatefulWidget {
  const MotionSharedId({super.key, required this.id, required this.child});

  final Object id;
  final Widget child;

  @override
  State<MotionSharedId> createState() => _MotionSharedIdState();
}

class _MotionSharedIdState extends State<MotionSharedId> {
  final _key = GlobalKey();
  SharedElementController? _scope;

  Rect? _measure() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Establishes the dependency so we rebuild when flights start/end, and
    // caches the controller for use in dispose (where context lookups fail).
    _scope = MotionSharedScope._maybeOf(context);
  }

  @override
  void dispose() {
    _scope?.unregister(widget.id, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _scope;
    // Register (idempotent). `this` is the identity token: a flight only fires
    // when a *different* element takes over the id, not when this one moves.
    controller?.register(widget.id, this, _measure, widget.child);
    final flying = controller?.isFlying(widget.id) ?? false;

    return KeyedSubtree(
      key: _key,
      // Hide the real widget while its copy is flying, keeping its layout box
      // so the flight lands on the correct rect.
      child: Opacity(opacity: flying ? 0.0 : 1.0, child: widget.child),
    );
  }
}
