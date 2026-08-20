# Architecture

## The FLIP technique in one paragraph

You want a widget to appear to slide smoothly when its layout changes. But
Flutter's layout is imperative and one-shot: the framework computes the new
position and paints it there. To animate the transition, you need to:

1. **F**irst — remember where the widget was before the layout change.
2. **L**ast — measure where the widget is *after* the layout change.
3. **I**nvert — apply a `Transform.translate` equal to `previous - current`.
   The widget is now sitting at its new position but visually appears at the old one.
4. **P**lay — animate that translation to `Offset.zero` over time.

The trick is entirely visual — the layout position is already correct from
frame one. This makes FLIP scale to complex layouts (Wrap, Grid, custom
layouts) that would be a nightmare to animate imperatively.

## Data flow

```
┌────────────────────────────────────────┐
│  LayoutMotion.build                    │
│    - render child (already at "Last") │
│    - schedule post-frame measurement   │
│    - AnimatedBuilder wraps in           │
│      Transform.translate(fromOffset)   │
└──────────────┬─────────────────────────┘
               │ SchedulerBinding.addPostFrameCallback
               ▼
┌────────────────────────────────────────┐
│  _scheduleMeasurement                  │
│    current = boxKey.RenderBox bounds   │
│    if (previous != null && diff)       │
│      fromOffset = previous - current   │
│      controller.forward(from: 0)       │
│    previous = current                   │
└────────────────────────────────────────┘
```

## Why post-frame, not `didUpdateWidget`

`didUpdateWidget` runs when the widget config changes, but not when the
*layout* changes due to ancestor changes (e.g., a sibling being added).
Post-frame callbacks fire after every frame regardless of why the layout
changed, so we catch all reflow events.

The cost is one measurement per frame per `LayoutMotion` instance. For
large lists this could add up, but a `RenderBox.localToGlobal + size` read
is cheap (no layout re-run). If profiling shows it matters, we can move to
a `RenderObject` subclass that hooks into paint directly (planned for v0.2).

## Why `Transform.translate`, not `Positioned`

Two reasons:
1. **Non-Stack parents**: `LayoutMotion` should work inside a `Column`, `Wrap`,
   `Grid`, or any custom layout — `Positioned` requires a `Stack`.
2. **No layout impact**: `Transform.translate` shifts painting only, not
   layout. The parent's layout stays computed at the child's real position,
   so surrounding widgets don't move mid-animation.

## `AnimatedLayout` convenience wrapper

Instead of manually wrapping every child in `LayoutMotion`, you get a
`wrap(child)` helper:

```dart
AnimatedLayout(
  builder: (context, wrap) => Column(
    children: items.map((i) => wrap(Card(key: ValueKey(i), ...))).toList(),
  ),
);
```

Under the hood `wrap` returns `LayoutMotion(key: child.key, child: child)`.
The **stable key on each child is essential** — Flutter uses it to preserve
element identity across rebuilds. Without it, `LayoutMotion`'s state
(`_previousBounds`) resets on every rebuild and animation doesn't play.

## `animateSize` — the caveat

Setting `animateSize: true` scales the child via `Transform` when the size
changes. This produces the size animation but *distorts* the child's
rendering (text stretches, images blur). We keep it off by default because
`AnimatedContainer` / `AnimatedCrossFade` are usually better for actual
size changes. FLIP is at its best for **position** animation.

## Beyond `LayoutMotion` (0.1.0)

- **`MotionGroup`** — enter/exit (an `AnimatePresence` equivalent) + layout.
  Rather than needing an `Element` subclass, it keeps a per-child state ("slot")
  with an `AnimationController`: entering children run forward; a removed child
  is kept mounted and run in reverse, then removed on `dismissed`; survivors are
  wrapped in `LayoutMotion` so they FLIP into place. Exit transitions are
  paint-only, so the layout reflows in one discrete step (no jitter).
- **`MotionSharedScope` / `MotionSharedId`** — within-page shared elements. A
  per-scope controller tracks each id's holders and global rect; on a genuine
  hand-off (a *different*, newer element takes the id) it flies an overlay copy
  from the old rect to the new one and hides the non-active holder. The active
  holder is chosen by **birth order**, not registration order, so lazy slivers
  (which build during layout) don't confuse it.
- **`SpringCurve`** — a `SpringSimulation` sampled onto `t ∈ [0,1]`, so springy
  motion works through the existing curve path (no controller rework).

## Still not done

- **Cross-*route* shared elements** — today's shared elements are within-page;
  route-to-route hand-off is Flutter `Hero`'s job.
- **Velocity-preserving spring** — `SpringCurve` is fixed-duration; true physics
  interruption (carrying momentum) is future work.
- **Virtualisation** — best for modest collections; no windowing yet.
