# flip_layout — Feature Specification

Behavioral contract for the animations. Guarantees are pinned by
`test/flip_layout_test.dart`.

## -1. `MotionSharedScope` / `MotionSharedId` — shared-element transitions

- Under one `MotionSharedScope`, at most one `MotionSharedId` per `id` is active
  at a time (the shared-element contract).
- The scope tracks each id's global rect per frame. When an id's rect changes
  between frames (the same element moved, or one element replaced another with
  the same id at a new location), a copy of the current child is flown in an
  `Overlay` from the previous rect to the new rect over `duration`/`curve`.
- While an id is in flight, the real widget holding that id renders at opacity 0
  but keeps its layout box, so the flight lands on the correct destination rect.
- The flight uses `Positioned.fromRect`, so a **size-flexible** child
  interpolates its layout at each frame (not a uniform scale).
- Overlay entry + controller are removed/disposed when the flight completes.
- Route-to-route transitions are out of scope — use Flutter's `Hero`.
- **Active-holder pick.** When multiple `MotionSharedId`s share an id at once,
  the **newest by birth order** (most recently created `State`) is the active
  (visible, flight-destination) holder — NOT the last-registered, so lazy
  slivers building during layout don't mispick. This is a heuristic; see
  `doc/ARCHITECTURE.md` for its limits.
- **Flight shuttle.** By default the flight carries the **destination** child.
  `crossFade: true` shows the built-in cross-fade of source→destination instead.
  A `flightShuttleBuilder(context, animation, fromChild, toChild)` replaces the
  in-flight widget entirely; `animation` runs 0→1 shaped by the scope `curve`.
  Flight tunables are snapshotted per flight, so a mid-flight scope rebuild does
  not mutate an in-progress flight.

## 0. `MotionGroup` — declarative collection (layout + presence)

Given a keyed `children` list and a `builder` that lays them out, `MotionGroup`
animates the collection as `children` changes:

- **Enter**: a child whose key is new since the last build animates in (default
  fade + scale, via `transitionBuilder`, `0→1`).
- **Exit**: a child whose key disappears from `children` MUST be **kept
  mounted** and animated out (`1→0`) *before* it is removed from the tree. Only
  after its animation reaches `dismissed` is it actually removed. (This is the
  `AnimatePresence` guarantee — you can't animate a widget Flutter has already
  disposed.)
- **Layout**: surviving children slide to their new positions via `LayoutMotion`
  (FLIP) when siblings enter/leave or the order changes.
- Exit transitions are **paint-only** (opacity/scale), so an exiting child keeps
  its layout footprint until removed — survivors reflow as a single discrete
  step (no continuous-resize jitter).
- `stagger`: successive children in the same enter-batch start `stagger` apart.
- `exitStagger`: successive children in the same *removal* batch start their exit
  `exitStagger` apart; each leaver stays fully visible until its turn. Collapses
  to zero under reduced motion.
- `animateInitial`: when false, the first batch appears at rest (no enter
  animation).
- Every child MUST have a unique `Key` (asserted).
- Controllers are created per child and disposed on exit/removal and on widget
  dispose.
- `transitionBuilder` drives enter (0→1); `exitTransitionBuilder` (when given)
  drives exit (1→0), else `transitionBuilder` is reused for both.
- **Lifecycle callbacks.** `onEnter(key)` fires once when a child's enter
  transition completes (NOT for a first batch placed instantly via
  `animateInitial: false`). `onExitComplete(key)` fires once when a leaving
  child's exit transition finishes and it is removed from the tree.
- **Spring slide.** When a `spring` (`MotionSpring`) is in effect (own arg or via
  `MotionConfig`), the survivors' FLIP *layout slide* is physics-timed and
  velocity-preserving (§1); enter/exit transitions still use `duration`/`curve`.
- **No virtualisation.** `MotionGroup` manages every child at once and keeps
  exiting ones mounted. In debug builds it warns once when the child count
  exceeds `MotionGroup.debugChildCountWarningThreshold` (default 150). Large,
  scrolling collections should use `AnimatedList` / `SliverAnimatedList`.

## 0b. `MotionConfig` — inherited defaults

- Provides subtree-wide `duration`/`curve`/`stagger`/`spring` defaults.
  Resolution for any value: the widget's own argument → nearest `MotionConfig` →
  built-in default (spring default is null = curve path).
- `reduceMotion`: when true (or, when null, when `MediaQuery.disableAnimations`
  is set) every effective duration/stagger collapses to zero, so changes apply
  **instantly** with no slide/fade — `LayoutMotion` jumps to the new position
  and `MotionGroup` add/remove is immediate. Honouring the OS accessibility
  setting is automatic.

## 1. `LayoutMotion` — the FLIP loop

The FLIP technique: **F**irst/**L**ast measure, **I**nvert with a transform,
**P**lay the transform back to identity.

- After every frame, `LayoutMotion` measures its own bounds. If they differ
  from the previous frame's bounds, it applies an inverse
  `Transform.translate` equal to the delta and animates it to `Offset.zero`
  over `duration`/`curve`.
- **At rest the transform MUST be exactly identity.** On completion the
  inverse offset/scale are reset to zero/one.
- Mid-animation the moved child MUST actually be offset (it slides), not
  snapped to its final slot.
- **Interruptible**: if the layout changes again while a slide is in flight, the
  new slide starts from the element's *current on-screen* offset (not from a
  hard 0), so a reorder-during-reorder stays position-continuous — no jump.
- **Spring path** (`spring: MotionSpring`, own arg or inherited from
  `MotionConfig`): the inverse offset is driven per-axis by a live
  `SpringSimulation` on an unbounded controller (no fixed duration). On an
  interruption the current **velocity** is carried into the new spring, so
  momentum is preserved (not restarted from rest); it still settles exactly to
  identity. `duration`/`curve` are ignored for the position slide (a size
  `animateSize` scale, if enabled, still rides the curve path). Under reduced
  motion the spring is skipped (jump to the new position).

## 2. Measurement correctness (the two subtle guarantees)

1. **Untransformed measurement.** The measured `RenderBox` sits *above* the
   animating `Transform` (via a `MetaData` proxy). The in-flight transform
   therefore never feeds back into the next measurement → no jitter /
   oscillation, even if the parent rebuilds during an animation.
2. **Scroll invariance.** Inside a `Scrollable`, bounds are measured in scroll
   **content space** (viewport-relative position + scroll offset). Plain
   scrolling keeps content-space coordinates constant, so it MUST NOT be
   mistaken for a layout move and MUST NOT trigger an animation. Reordering,
   which changes content-space position, DOES animate.

## 3. Edge cases

- **First mount**: no previous bounds → no animation.
- **Degenerate bounds**: if either the previous or current rect is empty
  (zero width/height — e.g. offstage → onstage), the transition is skipped so a
  bogus large delta never animates.
- **Duration change** via `didUpdateWidget` updates the controller in place.

## 4. Size animation — `animateSize`

- Off by default. When on, size changes are animated with `Transform.scale`
  (alignment top-left), interpolating from `prev/current` scale to `1.0`.
- This is a **visual-only** effect: scaling stretches text/borders rather than
  re-laying-out. Use for uniform boxes.

## 5. Callbacks

- `onEnd` fires once each time a slide/scale animation completes.

## 6. `AnimatedLayout`

- Provides a `wrap(child)` helper that wraps each child in a `LayoutMotion`,
  forwarding `duration`/`curve`/`animateSize`.
- **Each wrapped child MUST carry a key** (e.g. `ValueKey`). Without a key the
  framework can't match widgets across a reorder and the animation is lost;
  this is asserted in debug mode.

## 7. Lifecycle / performance

- One `AnimationController` per `LayoutMotion`, disposed with the widget; the
  status listener is released automatically on dispose.
- Measurement is scheduled per real (state-level) build, not per animation
  frame — `AnimatedBuilder` rebuilds only its own subtree while animating.
- Measurement is `mounted`/`attached`-guarded; no `RenderBox` access after
  unmount.

## Not yet
Cross-*route* shared elements (use `Hero`), `SliverMotionGroup` virtualisation,
coordinated `LayoutGroup`, non-distorting `animateSize`, gesture-driven reorder.
