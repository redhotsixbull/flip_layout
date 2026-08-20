# Roadmap

## v0.0.1 — Scaffold (shipped)

- `LayoutMotion` widget — FLIP-based position animation
- `AnimatedLayout` convenience wrapper
- Optional `animateSize` (size interpolation via Transform.scale)

## v0.1.0 — Quality + declarative motion (shipped)

- **Robust `LayoutMotion`** — untransformed measurement (no jitter),
  scroll-content-space measurement (no spurious slide on scroll),
  **interruptible** slides (re-target from current offset, no snap), `onEnd`.
- **`MotionGroup`** — declarative collection animator: **enter/exit**
  (`AnimatePresence` equivalent) + FLIP layout in any layout (Wrap/Grid/Column),
  with `stagger`, `animateInitial`, and separate `exitTransitionBuilder`.
- **`MotionConfig`** — subtree-wide `duration`/`curve`/`stagger` defaults +
  reduced-motion (honours `MediaQuery.disableAnimations`).
- **`SpringCurve`** — tunable spring as a `Curve`.
- **`MotionSharedScope` / `MotionSharedId`** — within-page shared-element
  "magic move" (Hero-like, no route change).

## Next (v0.2+)

- **Velocity-preserving spring** — true physics interruption (carry momentum),
  beyond the current fixed-duration `SpringCurve`.
- **Shared-element polish** — a `flightShuttleBuilder` (custom in-flight widget),
  cross-fade between source/destination children, and opt-in for cross-*route*
  hand-off (today: within-page; routes → use `Hero`).
- **`LayoutGroup`** — coordinate multiple groups so they animate as one.
- **Gesture integration** — `Draggable`/`DragTarget` drag-reorder with FLIP.
- **Performance** — profile 1000+ items; consider RenderObject-based measurement
  and virtualisation.

## v1.0 — Stability

- API frozen
- Rendered examples site (Flutter Web demo)
- Performance benchmarks documented

## Explicit non-goals

- **A full Framer Motion port** — we compose with Flutter's built-ins
  (`AnimationController`, `SpringSimulation`, `GestureDetector`), not replace
  them. We fill the gaps they leave (declarative enter/exit + layout in any
  container; within-page shared elements).
- **Fancy vector / path animations** — that's Rive's job.
