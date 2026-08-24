import 'package:flutter/material.dart';

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
///
/// By default the flight interpolates the **destination** child's layout across
/// the moving rect. For a smoother morph between visually different source and
/// destination widgets, either set [crossFade] (the built-in shuttle dissolves
/// from the source child to the destination child), or supply a
/// [flightShuttleBuilder] to render a fully custom in-flight widget.
class MotionSharedScope extends StatefulWidget {
  const MotionSharedScope({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeInOutCubic,
    this.flightShuttleBuilder,
    this.crossFade = false,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  /// Optional builder for the widget shown *in flight* (in the overlay). It
  /// receives the flight [Animation] (0→1, already shaped by [curve]) and both
  /// the source child (the widget that previously held the id) and the
  /// destination child (the widget that now holds it), so you can render any
  /// transition between them. When null, the flight shows the destination child
  /// (or a cross-fade of both when [crossFade] is set).
  final MotionFlightShuttleBuilder? flightShuttleBuilder;

  /// When true (and no [flightShuttleBuilder] is given), the built-in flight
  /// cross-fades from the source child to the destination child instead of
  /// carrying only the destination child. Useful when the two ends look
  /// different (e.g. a thumbnail flying into a full detail card).
  final bool crossFade;

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
      flightShuttleBuilder: widget.flightShuttleBuilder,
      crossFade: widget.crossFade,
    );
  }

  @override
  void didUpdateWidget(covariant MotionSharedScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller
      ..duration = widget.duration
      ..curve = widget.curve
      ..flightShuttleBuilder = widget.flightShuttleBuilder
      ..crossFade = widget.crossFade;
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

/// Builds the in-flight widget for a shared-element transition. [animation] runs
/// 0→1 over the flight (already shaped by the scope's curve); [fromChild] is the
/// widget that previously held the id and [toChild] the one that now holds it.
typedef MotionFlightShuttleBuilder = Widget Function(
  BuildContext context,
  Animation<double> animation,
  Widget fromChild,
  Widget toChild,
);

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
    this.flightShuttleBuilder,
    this.crossFade = false,
  });

  final TickerProvider vsync;
  final OverlayState? Function() overlayOf;

  /// Flight tunables. Mutable so a rebuilt [MotionSharedScope] can update them;
  /// they take effect on the next flight (in-flight overlays keep their values).
  Duration duration;
  Curve curve;
  MotionFlightShuttleBuilder? flightShuttleBuilder;
  bool crossFade;

  // For each id, all elements currently claiming it (token -> registration).
  // The "active" (front) holder is the one that appeared most recently — by
  // birth order, NOT by per-frame registration order (a lazy GridView registers
  // its tiles during layout, *after* an overlay detail builds, so "last
  // registered" would be wrong).
  final Map<Object, Map<Object, _Registration>> _holders = {};
  final Map<Object, int> _birth = {};
  int _birthSeq = 0;

  final Map<Object, Rect> _lastRect = {};
  final Map<Object, Object> _lastHolder = {};
  final Map<Object, Widget> _lastChild = {};
  final Map<Object, Object> _resolvedHolder = {};
  final Set<Object> _flying = {};
  Set<Object> _seenLastProcess = {};
  bool _scheduled = false;

  bool isFlying(Object id) => _flying.contains(id);

  _Registration? _activeReg(Object id) {
    final map = _holders[id];
    if (map == null || map.isEmpty) return null;
    _Registration? best;
    var bestBirth = -1;
    for (final reg in map.values) {
      final b = _birth[reg.token] ?? -1;
      if (b >= bestBirth) {
        bestBirth = b;
        best = reg;
      }
    }
    return best;
  }

  /// Whether the element identified by [token] should be visible for [id]. It is
  /// hidden while a flight for that id is in progress, and also whenever a newer
  /// (on-top) element currently holds the id — so the source tile stays hidden
  /// while the detail is open, and reappears on fly-back.
  bool shouldShow(Object id, Object token) {
    if (_flying.contains(id)) return false;
    final active = _activeReg(id)?.token;
    return active == null || identical(active, token);
  }

  void register(Object id, Object token, Rect? Function() rectOf, Widget child) {
    _birth.putIfAbsent(token, () => _birthSeq++);
    (_holders[id] ??= {})[token] = _Registration(token, rectOf, child);
    _schedule();
  }

  void unregister(Object id, Object token) {
    final map = _holders[id];
    if (map != null) {
      map.remove(token);
      if (map.isEmpty) _holders.remove(id);
    }
    _birth.remove(token);
    // Re-run the diff so this frame's change is recorded.
    _schedule();
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
    final present = <Object>{};
    var resolvedChanged = false;
    for (final id in _holders.keys.toList()) {
      final reg = _activeReg(id);
      if (reg == null) continue;
      final rect = reg.rectOf();
      if (rect == null || rect.isEmpty) continue;
      present.add(id);

      // The newest (front) holder is the visible one for this id.
      if (!identical(_resolvedHolder[id], reg.token)) {
        _resolvedHolder[id] = reg.token;
        resolvedChanged = true;
      }

      if (_flying.contains(id)) {
        _lastRect[id] = rect;
        _lastHolder[id] = reg.token;
        _lastChild[id] = reg.child;
        continue;
      }

      final lastRect = _lastRect[id];
      final lastHolder = _lastHolder[id];
      final lastChild = _lastChild[id];
      // A flight fires only for a genuine hand-off: the id was present in the
      // previous frame too (continuity — so a tile recycled by a fast scroll,
      // which reappears after being absent, is NOT a swap), a *different*
      // element now holds it, and it landed somewhere new.
      final continuous = _seenLastProcess.contains(id);
      final swapped = lastHolder != null && !identical(lastHolder, reg.token);

      _lastRect[id] = rect;
      _lastHolder[id] = reg.token;
      _lastChild[id] = reg.child;

      if (continuous && swapped && lastRect != null && lastRect != rect) {
        _fly(id, lastRect, rect, fromChild: lastChild, toChild: reg.child);
      }
    }
    _seenLastProcess = present;
    // Reveal/hide holders whose active status changed (e.g. source tile hides
    // once the detail takes over the id, and reappears when it closes).
    if (resolvedChanged && !_disposed) notifyListeners();
  }

  void _fly(Object id, Rect from, Rect to,
      {required Widget toChild, Widget? fromChild}) {
    final overlay = overlayOf();
    if (overlay == null) {
      _lastRect[id] = to;
      return;
    }
    _flying.add(id);
    notifyListeners(); // real widget with this id hides itself

    // Snapshot the flight tunables so a mid-flight scope rebuild can't mutate
    // this flight's look; a later flight picks up the new values.
    final flightCurve = curve;
    final shuttleBuilder = flightShuttleBuilder;
    final wantsCrossFade = crossFade;
    final source = fromChild ?? toChild;

    final controller = AnimationController(vsync: vsync, duration: duration);
    final curved = CurvedAnimation(parent: controller, curve: flightCurve);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: curved,
        builder: (context, _) {
          final t = curved.value;
          final rect = Rect.lerp(from, to, t)!;
          // Positioned.fromRect gives the child tight rect constraints, so a
          // size-flexible child re-lays-out at each interpolated size (true
          // layout interpolation, not a scale). Give shared children no fixed
          // size for the smoothest result. The Material provides a proper text
          // style context in the overlay (otherwise Text shows the yellow
          // "missing style" underline).
          return Positioned.fromRect(
            rect: rect,
            child: Material(
              type: MaterialType.transparency,
              child: _buildShuttle(
                  context, curved, source, toChild, shuttleBuilder, wantsCrossFade),
            ),
          );
        },
      ),
    );
    overlay.insert(entry);
    controller.forward().whenCompleteOrCancel(() {
      entry.remove();
      curved.dispose();
      controller.dispose();
      _flying.remove(id);
      if (!_disposed) notifyListeners(); // reveal the real widget
    });
  }

  /// Builds the widget carried in the overlay during a flight: a custom
  /// [flightShuttleBuilder] if given, else a cross-fade of source→destination
  /// (when [crossFade] is on and the ends differ), else just the destination.
  Widget _buildShuttle(
    BuildContext context,
    Animation<double> animation,
    Widget fromChild,
    Widget toChild,
    MotionFlightShuttleBuilder? builder,
    bool wantsCrossFade,
  ) {
    if (builder != null) return builder(context, animation, fromChild, toChild);
    if (wantsCrossFade && !identical(fromChild, toChild)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(opacity: ReverseAnimation(animation), child: fromChild),
          FadeTransition(opacity: animation, child: toChild),
        ],
      );
    }
    return toChild;
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
    final show = controller?.shouldShow(widget.id, this) ?? true;

    return KeyedSubtree(
      key: _key,
      // Hidden while a copy is flying, and while a newer element holds this id
      // (keeping the layout box so flights land on the correct rect).
      child: Opacity(opacity: show ? 1.0 : 0.0, child: widget.child),
    );
  }
}
