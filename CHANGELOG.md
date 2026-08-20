## 0.1.0

- **New:** `MotionConfig` — set `duration`/`curve`/`stagger` defaults for a
  subtree once, and honour reduced-motion (config flag, or the OS accessibility
  setting automatically) by skipping animations. `LayoutMotion`/`MotionGroup`
  `duration`/`curve`/`stagger` are now nullable and inherit from it.
- **New:** `MotionGroup.exitTransitionBuilder` — give leaving children a
  different transition from entering ones.
- **New:** `LayoutMotion` slides are now **interruptible** — a layout change
  mid-slide re-targets from the current on-screen position instead of snapping
  to 0, so rapid reorders/filters stay smooth (also benefits `MotionGroup`).
- **New:** `MotionGroup` — a declarative collection animator that does
  **enter/exit** (an `AnimatePresence` equivalent) + **layout** (FLIP) in any
  layout (`Wrap`, `GridView`, `Column`, …). Just change the `children` list.
  Supports `stagger`, `animateInitial`, and a custom `transitionBuilder`.
- **Example:** redesigned around `MotionGroup` — Filter (a `Wrap` that no
  built-in animates), Reorder (FLIP + stagger), and Add/remove (enter/exit).
  The old Expand demo was removed (that's `AnimatedSize`/`ExpansionTile`'s job,
  and mixing FLIP with a continuous resize caused jitter). Runs on web;
  deep-linkable via `?demo=<id>`.
- **Docs:** README repositioned around `MotionGroup` with screenshots and a
  "When *not* to use this" section; `docs/` renamed to `doc/` (pub convention);
  added pubspec topics.
- Bundles all `0.0.2` fixes below.

## 0.0.2

- **Fix:** measurement now reads the untransformed layout position (via a
  `MetaData` proxy above the `Transform`), so an in-flight animation no longer
  contaminates the next measurement — eliminates jitter/oscillation.
- **Fix:** inside a `Scrollable`, positions are measured in scroll *content*
  space, so plain scrolling no longer triggers spurious slide animations.
- **Fix:** the resting transform settles exactly to identity on completion.
- **Fix:** degenerate (zero-size / offstage) transitions are skipped instead of
  animating a bogus delta.
- **API:** added `onEnd` callback; `AnimatedLayout` forwards `animateSize` and
  asserts each wrapped child has a key.
- Docs: added `docs/SPEC.md`; added tests for the FLIP inverse, scroll
  invariance, the key assertion, and `onEnd`.

## 0.0.1

- Initial scaffold: `LayoutMotion` widget (FLIP-based auto layout animation) and `AnimatedLayout` convenience wrapper.
