# API reference

## `MotionGroup`

Declarative collection animator: enter + exit + FLIP layout in any layout.

```dart
MotionGroup({
  Key? key,
  required List<Widget> children,       // each MUST have a unique Key
  required Widget Function(BuildContext, List<Widget> children) builder,
  Duration? duration,                   // inherits MotionConfig, else 300ms
  Curve? curve,                         // inherits MotionConfig, else easeOutCubic
  MotionSpring? spring,                 // velocity-preserving reflow slide (below)
  Duration? stagger,                    // delay between entering children
  Duration? exitStagger,                // delay between leaving children
  bool animateInitial = true,           // animate the first batch in
  Widget Function(BuildContext, Animation<double>, Widget) transitionBuilder, // enter (0→1)
  Widget Function(BuildContext, Animation<double>, Widget)? exitTransitionBuilder, // exit (1→0)
  void Function(Key key)? onEnter,        // a child finished entering
  void Function(Key key)? onExitComplete, // a child finished exiting (removed)
})

// Debug-only: warn once past this many children (no virtualisation). null silences.
MotionGroup.debugChildCountWarningThreshold = 150;
```

- Add / remove / reorder the `children` list and it animates automatically.
- **Enter**: children new since the last build fade + scale in (default).
- **Exit**: removed children are kept mounted and animated out *before* removal
  (an `AnimatePresence` equivalent — Flutter can't animate a widget it already
  disposed).
- **Layout**: survivors slide (FLIP) to their new positions.
- `builder` arranges the animation-wrapped children (`Wrap`, `GridView`,
  `Column`, …).

```dart
MotionGroup(
  children: [for (final t in visibleTags) Chip(key: ValueKey(t), label: Text(t))],
  builder: (context, children) => Wrap(spacing: 8, children: children),
)
```

---

## `LayoutMotion`

Position-only FLIP for a single widget: it slides when *its own* position
changes due to a layout change in ancestors.

```dart
LayoutMotion({
  Key? key,                 // stable key (e.g. ValueKey(id)) so the Element persists
  required Widget child,
  Duration? duration,       // inherits MotionConfig, else 300ms
  Curve? curve,             // inherits MotionConfig, else easeOutCubic
  MotionSpring? spring,     // physics slide (inherits MotionConfig); overrides duration/curve
  bool animateSize = false, // also scale on size change (visual-only, distorts)
  VoidCallback? onEnd,      // fires when a slide completes
})
```

- Measures its **untransformed** bounds above the animating `Transform`, so an
  in-flight slide never contaminates the next measurement (no jitter).
- Inside a `Scrollable`, measures in scroll-**content** space, so scrolling
  doesn't trigger a spurious slide.
- **Interruptible**: a layout change mid-slide re-targets from the current
  on-screen offset (no jump).

---

## `MotionConfig`

Inherited defaults + reduced-motion for a subtree.

```dart
MotionConfig({
  Key? key,
  Duration? duration,
  Curve? curve,
  Duration? stagger,
  MotionSpring? spring,   // default velocity-preserving spring for slides
  bool? reduceMotion,   // null → follows MediaQuery.disableAnimations
  required Widget child,
})
```

Resolution for any value: **the widget's own argument → nearest `MotionConfig`
→ built-in default**. When motion is reduced, durations collapse to zero and
changes apply instantly (`LayoutMotion` jumps, `MotionGroup` add/remove is
immediate).

---

## `SpringCurve`

A tunable spring as a `Curve` — usable anywhere a curve is accepted.

```dart
SpringCurve({double mass = 1.0, double stiffness = 180.0, double damping = 12.0})
```

Samples a `SpringSimulation` normalised onto `t ∈ [0,1]`. Lower `damping`
overshoots/bounces; higher `damping` settles cleanly. It is a spring *look*
(fixed-duration), not velocity-preserving physics.

```dart
MotionConfig(curve: SpringCurve(stiffness: 220, damping: 14), child: ...)
```

---

## `MotionSpring`

**Velocity-preserving** physics for position slides (vs `SpringCurve`, which is
a fixed-duration spring *look*). No fixed duration; a mid-slide re-target carries
momentum.

```dart
MotionSpring({double mass = 1.0, double stiffness = 180.0, double damping = 20.0})
MotionSpring.gentle   // near-critically-damped, minimal overshoot
MotionSpring.bouncy   // underdamped, visible overshoot
```

Pass via `spring:` on `LayoutMotion`/`MotionGroup`, or as a `MotionConfig`
default. Drives the **position slide only** (enter/exit still use `duration`/
`curve`). Skipped under reduced motion.

```dart
MotionGroup(spring: const MotionSpring(stiffness: 220, damping: 16), ...)
```

---

## `MotionSharedScope` / `MotionSharedId`

Shared-element "magic move" **within a page** (no route change) — the thing
`Hero` only does across routes.

```dart
MotionSharedScope({
  Key? key,
  required Widget child,
  Duration duration = const Duration(milliseconds: 350),
  Curve curve = Curves.easeInOutCubic,
  bool crossFade = false, // built-in source→destination dissolve in flight
  MotionFlightShuttleBuilder? flightShuttleBuilder, // custom in-flight widget
})

MotionSharedId({Key? key, required Object id, required Widget child})

// flightShuttleBuilder signature:
// Widget Function(BuildContext, Animation<double> animation, Widget fromChild, Widget toChild)
```

- Give two widgets the same `id` under one scope. When one hands the id off to
  another (a real swap — e.g. grid tile → detail), a copy flies from the old
  rect to the new one; the source stays hidden until it flies back.
- A flight fires only on a genuine hand-off, **not** when the same element
  merely moves (scrolling / relayout) or is recycled by a lazy list.
- Shared children should be **size-flexible** (no fixed width/height) so the
  flight interpolates layout smoothly.
- By default the flight carries the destination child. Set `crossFade: true` to
  dissolve source→destination, or `flightShuttleBuilder` for a custom in-flight
  widget. The active holder among several is chosen by **birth order** (a
  heuristic — see [`ARCHITECTURE.md`](ARCHITECTURE.md)).

**Recommended pattern**: don't *replace* the origin screen with the detail —
**layer** the detail on top (keep the origin mounted). That preserves its
scroll/state and gives you fly-back for free:

```dart
MotionSharedScope(
  child: Stack(children: [
    Grid(...),                                   // stays mounted
    if (selected != null) DetailOverlay(selected), // layered on top
  ]),
)
```

---

## `AnimatedLayout` (legacy)

A thin `wrap`-helper wrapper around `LayoutMotion` (position-only, no
enter/exit). Prefer `MotionGroup` for collections.

```dart
AnimatedLayout({
  Key? key,
  required Widget Function(BuildContext, Widget Function(Widget child) wrap) builder,
  Duration duration = const Duration(milliseconds: 300),
  Curve curve = Curves.easeOutCubic,
  bool animateSize = false,
})
```

Each wrapped child must carry a key (asserted).

---

## When NOT to use this

Use a Flutter built-in when it already fits — don't fight it:

- **Expand / collapse one widget's size** → `AnimatedSize` / `ExpansionTile`.
  (FLIP is for *discrete* position changes; mixing it with a *continuous*
  resize causes jitter.)
- **Drag-to-reorder a list** → `ReorderableListView`.
- **A huge, lazily-built list** → `AnimatedList` / `SliverAnimatedList`.
- **Cross-*route* shared elements** → `Hero`.
- **Just fading one widget in/out** → `AnimatedOpacity` / `AnimatedSwitcher`.
