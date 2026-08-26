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

## v0.2.0 — Physics + shared-element polish + lifecycle (shipped)

- **`MotionSpring`** — velocity-preserving spring: live `SpringSimulation` on an
  unbounded controller, so a mid-slide re-target **carries momentum**. Wired
  through `LayoutMotion`/`MotionGroup`/`MotionConfig` via `spring:`;
  `SpringCurve` stays for the simple fixed-duration case.
- **Shared-element polish** — `flightShuttleBuilder` (custom in-flight widget)
  and `crossFade` (built-in source→destination dissolve); birth-order heuristic
  and its limits documented.
- **`MotionGroup` lifecycle** — `onEnter`/`onExitComplete` callbacks and
  `exitStagger` (cascade leavers).
- **Large-collection guard** — one-time debug warning past
  `MotionGroup.debugChildCountWarningThreshold`.

## v0.2.1 — Docs that can't rot (shipped)

- **README carries no version numbers** ✅
- **`docs_freshness_test.dart` + `readme_snippets_test.dart`** fail the suite if
  the docs drift from the code ✅

## Next (v0.3+)

- **Stop exporting `SharedElementController`** — it's the machinery behind
  `MotionSharedScope`, reachable only through a private lookup, and is public
  today only because the whole library file is exported.

- **Cross-*route* shared-element** opt-in (today: within-page; routes → `Hero`).
- **`SliverMotionGroup`** — virtualised group that only animates on-screen items
  (integrate with `SliverAnimatedList`); profile 1000+ items.
- **Non-distorting `animateSize`** — a clip/align-based size option.
- **`LayoutGroup`** — coordinate multiple groups so they animate as one.
- **Gesture integration** — `Draggable`/`DragTarget` drag-reorder with FLIP.

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
