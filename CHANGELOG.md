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
