## 0.2.1

Documentation hygiene — no behaviour changes.

- **The README no longer carries version numbers.** The status line restated the
  release and Install pinned `^0.2.0`; both had to be edited every release, and
  that is exactly what went stale in a sibling package (a README describing a
  shipped release as a prerelease, served by pub.dev for the whole release).
  `pubspec.yaml` is the version, `CHANGELOG.md` is the history, the pub.dev
  badge renders the current number. Install is now `flutter pub add flip_layout`.
- **New: `test/docs_freshness_test.dart`** — fails the suite if the README
  contains a version literal, if `CHANGELOG.md`'s newest entry doesn't match
  `pubspec.yaml`, or if a public type has no entry in `doc/API.md`.
- **New: `test/readme_snippets_test.dart`** — compile-checks (and mounts) every
  Dart snippet in the README and `doc/API.md` against the real API: the
  `MotionGroup` example, the layered shared-element pattern, `crossFade` /
  `flightShuttleBuilder`, `MotionConfig`, both spring flavours, `LayoutMotion`,
  and every documented constructor argument across `MotionGroup`,
  `LayoutMotion`, `AnimatedLayout`, `MotionSharedScope` and `MotionConfig`.
- `SharedElementController` is recorded in the guard's allowlist as internal —
  it is exported only because the whole library file is, and is reachable solely
  through a private lookup. Dropping it from the public export is on the roadmap.

## 0.2.0

Stable release of the 0.2.0 line (the `0.2.0-dev.*` notes below are the full
feature history). Headline additions since `0.1.x`:

- `MotionSpring` — a **velocity-preserving** spring for position slides, so a
  reorder mid-slide carries the element's momentum into the new target.
- Shared-element flight polish — `MotionSharedScope.flightShuttleBuilder` and
  `crossFade`.
- `MotionGroup` lifecycle — `onEnter(key)` / `onExitComplete(key)` callbacks and
  `exitStagger`, plus a one-time debug warning past
  `debugChildCountWarningThreshold` (default 150).
- **Example:** a new **Stress** tab — an in-app performance harness with a live
  FPS / build / raster / jank readout, driving a single `MotionGroup` up to 300
  churning children.
- **Docs:** the README now has a measured **Performance** section.

All public API additions are backward compatible with `0.1.x`.

## 0.2.0-dev.1

Prerelease of the 0.2.0 line for testing on pub.dev before the stable cut.

- **New:** `MotionSpring` — a **velocity-preserving** spring for position slides.
  Unlike `SpringCurve` (a fixed-duration spring *look*), it drives the slide with
  a live `SpringSimulation` on an unbounded controller, so a re-order mid-slide
  carries the element's **momentum** into the new target. Wire it via a new
  `spring:` argument on `LayoutMotion`/`MotionGroup`, or a `spring:` default on
  `MotionConfig`. `SpringCurve` still works for the simple curve path.
- **New:** shared-element flight polish — `MotionSharedScope.flightShuttleBuilder`
  (render a fully custom in-flight widget, given the source and destination
  children + the flight animation) and `MotionSharedScope.crossFade` (the
  built-in flight dissolves source→destination instead of carrying only the
  destination child). The example Shared tab now cross-fades tile→detail.
- **New:** `MotionGroup` lifecycle + exit stagger — `onEnter(key)` /
  `onExitComplete(key)` callbacks and an `exitStagger` so a batch of leaving
  children cascade out one-after-another. The example Add/remove tab shows both
  (a "Clear" button + a live status line).
- **New:** large-collection guard — `MotionGroup` prints a one-time debug warning
  when its child count exceeds `MotionGroup.debugChildCountWarningThreshold`
  (default 150), since it isn't virtualised. README/SPEC steer big lists to
  `AnimatedList` / `SliverAnimatedList`.
- **Docs:** documented the shared-element **birth-order heuristic** and its limits
  in `doc/ARCHITECTURE.md`; SPEC/ROADMAP/README updated for the above.
- **Tests:** added coverage for the flight shuttle + cross-fade, three-holder
  birth-order pick, rapid open/close and flight-interrupted-by-flight, spring
  slide + velocity-continuous re-target, the large-count warning, and the
  lifecycle callbacks + exit stagger.
- All public API additions are backward compatible with `0.1.x`.

## 0.1.0

- **New:** `MotionSharedScope` + `MotionSharedId` — shared-element "magic move"
  transitions **within a page** (grid→detail, list→hero) with no route change,
  the thing Flutter's `Hero` only does across routes. Example gains a Shared tab.
- **New:** `SpringCurve` — a tunable spring (mass/stiffness/damping) as a
  `Curve`, for overshoot-and-settle slides anywhere a curve is accepted.
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
