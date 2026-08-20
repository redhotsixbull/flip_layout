# Roadmap

## v0.0.1 — Scaffold (shipped)

- `LayoutMotion` widget — FLIP-based position animation
- `AnimatedLayout` convenience wrapper
- Optional `animateSize` (size interpolation via Transform.scale)

## v0.1 — Animation quality

- **Spring driver** — `SpringSimulation` alternative to `Curve` interpolation
- **`onLayoutChange` callback** — notify subscribers when a reflow triggers animation
- **Interruptible animations** — new layout change mid-animation should smoothly re-target, not snap
- **Performance** — profile with 1000+ items, consider RenderObject-based measurement

## v0.2 — Framer Motion parity features

- **Shared elements across routes** (`SharedLayoutId`) — hero-like transitions but for arbitrary widgets
- **`AnimatePresence`** — enter and exit animations for conditionally-rendered widgets
- **`LayoutGroup`** — coordinate multiple `LayoutMotion`s so they animate as one
- **Gesture integration** — dragging a widget commits to a new position with FLIP smoothing

## v0.5 — Advanced use cases

- **Scroll-linked animations** — position animations tied to scroll offset
- **Automatic reorder detection** — plug in with `Draggable` / `DragTarget` for FLIP-animated drag reorder
- **`ImplicitlyAnimatedGrid`** — a `Wrap` / `GridView` replacement where children auto-animate

## v1.0 — Stability

- API frozen
- Rendered examples site (docs.page or Flutter Web demo)
- Performance benchmarks documented

## Explicit non-goals

- **A full Framer Motion port** — FLIP is one piece. Curves, springs,
  variants, gestures — Flutter has strong built-ins for those (`AnimationController`,
  `SpringSimulation`, `GestureDetector`). We compose with them, not replace them.
- **Fancy vector / path animations** — that's Rive's job.
