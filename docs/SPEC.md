# flip_layout — Feature Specification

Behavioral contract for the FLIP animation. Guarantees are pinned by
`test/flip_layout_test.dart`.

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

## Not yet (out of scope for 0.0.x)
Shared-element transitions (`layoutId`), enter/exit (`AnimatePresence`), spring
physics, coordinated `LayoutGroup`.
